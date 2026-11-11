extends Node

@onready var input_router: InputRouter = get_node("/root/InputRouterSingleton")

signal battle_party_chosen(index: int)
signal battle_text_finished
signal mansion_switch_answered(pressed: bool)

var adjacent_worlds: Dictionary = {}
var current_world_grid := Vector2i.ZERO
var map_waypoints: Dictionary = {}
var waypoint_ui: Node
var edge_travel_busy := false
var edge_sky: Node2D
signal progression_confirmed
signal progression_choice_made(value: int)

const SETUP_SAVE_PATH := "user://m3_setup.cfg"
const DataPaths = preload("res://scripts/game_data_paths.gd")
var SAVE_DIR := "user://saves"
var SAVE_INDEX_PATH := "user://saves/index.cfg"
const CraftingData = preload("res://scripts/crafting_data.gd")
const ItemData = preload("res://scripts/item_data.gd")
const FieldMoveData = preload("res://scripts/field_move_data.gd")
const PokemonData = preload("res://scripts/pokemon_data.gd")
const PokemonEcology = preload("res://scripts/pokemon_ecology.gd")
const BattleEngine = preload("res://scripts/battle_engine.gd")
const PokemonState = preload("res://scripts/pokemon_state.gd")
const SourceEventData = preload("res://scripts/source_event_data.gd")
const FieldMoveRadial = preload("res://scripts/field_move_radial.gd")
const SOURCE_MALE_SYMBOL = preload("res://assets/source_exact/global/male_symbol1.png")
const SOURCE_FEMALE_SYMBOL = preload("res://assets/source_exact/global/female_symbol1.png")

const FIELD_MOVE_WHEEL_ORDER := [
    "BUILD", "CUT", "FLY", "SURF", "DIG",
    "RIDE", "SMASH", "TELEPORT", "FLASH", "CHARM",
    "POWER", "REPEL", "ATTACK", "HEADBUTT", "PAINT"
]
const FIELD_MOVE_REPRESENTATIVES := {
    "BUILD":"machop", "CUT":"chikorita", "FLY":"fearow",
    "SURF":"blastoise", "DIG":"diglett", "RIDE":"tauros",
    "SMASH":"geodude", "TELEPORT":"abra", "FLASH":"charmander",
    "CHARM":"clefairy", "POWER":"pikachu", "REPEL":"grimer",
    "ATTACK":"poochyena", "HEADBUTT":"squirtle", "PAINT":"smeargle"
}

const PLAYER_TEXTURES := [
    preload("res://assets/player_green.png"),
    preload("res://assets/player_blue.png"),
    preload("res://assets/player_red.png"),
    preload("res://assets/player_gold.png"),
    preload("res://assets/player_orange.png"),
    preload("res://assets/player_indigo.png"),
    preload("res://assets/player_cyan.png"),
    preload("res://assets/player_lime.png"),
    preload("res://assets/player_magenta.png"),
    preload("res://assets/player_wine.png"),
    preload("res://assets/player_yellow.png"),
    preload("res://assets/player_brown.png"),
    preload("res://assets/player_olive.png"),
    preload("res://assets/player_teal.png"),
    preload("res://assets/player_bright_red.png"),
    preload("res://assets/player_purple.png"),
    preload("res://assets/player_pink.png")
]
const PLAYER_RUN_TEXTURES := [
    preload("res://assets/player_run_green.png"),
    preload("res://assets/player_run_blue.png"),
    preload("res://assets/player_run_red.png"),
    preload("res://assets/player_run_gold.png"),
    preload("res://assets/player_run_orange.png"),
    preload("res://assets/player_run_indigo.png"),
    preload("res://assets/player_run_cyan.png"),
    preload("res://assets/player_run_lime.png"),
    preload("res://assets/player_run_magenta.png"),
    preload("res://assets/player_run_wine.png"),
    preload("res://assets/player_run_yellow.png"),
    preload("res://assets/player_run_brown.png"),
    preload("res://assets/player_run_olive.png"),
    preload("res://assets/player_run_teal.png"),
    preload("res://assets/player_run_bright_red.png"),
    preload("res://assets/player_run_purple.png"),
    preload("res://assets/player_run_pink.png")
]
const PLAYER_COLOR_NAMES := [
    "GREEN", "BLUE", "RED", "GOLD", "ORANGE", "INDIGO", "CYAN",
    "LIME", "MAGENTA", "WINE", "YELLOW", "BROWN", "OLIVE", "TEAL",
    "BRIGHT RED", "PURPLE", "PINK"
]
const PLAYER_COLOR_VALUES := [
    Color(0.184314, 0.356863, 0.258824, 1.0),
    Color(0.188235, 0.309804, 0.545098, 1.0),
    Color(0.517647, 0.215686, 0.215686, 1.0),
    Color(0.501961, 0.360784, 0.133333, 1.0),
    Color(0.941176, 0.313725, 0.188235, 1.0),
    Color(0.313725, 0.282353, 0.972549, 1.0),
    Color(0.0, 1.0, 1.0, 1.0),
    Color(0.219608, 0.721569, 0.094118, 1.0),
    Color(1.0, 0.0, 1.0, 1.0),
    Color(0.690196, 0.188235, 0.376471, 1.0),
    Color(1.0, 1.0, 0.0, 1.0),
    Color(0.470588, 0.313725, 0.094118, 1.0),
    Color(0.419608, 0.556863, 0.137255, 1.0),
    Color(0.0, 0.498039, 0.498039, 1.0),
    Color(1.0, 0.0, 0.0, 1.0),
    Color(0.627451, 0.125490, 0.941176, 1.0),
    Color(1.0, 0.450980, 0.784314, 1.0)
]
const PLAYER_MODEL_NAMES := [
    "red", "leaf", "gold", "kris", "brendan", "may", "hilbert",
    "hilda", "rosa", "calem", "serena", "chase", "elaine",
    "gloria", "mark", "mint", "lunick", "summer", "kellyn",
    "agatha",
    "blaine1",
    "blaine2",
    "blue",
    "brock",
    "bruno",
    "bugsy",
    "chuck",
    "clair",
    "erika",
    "falkner",
    "giovanni1",
    "giovanni2",
    "janine",
    "jasmine",
    "karen1",
    "karen2",
    "koga",
    "lance",
    "lorelei",
    "lt. surge",
    "misty1",
    "misty2",
    "morty",
    "pryce1",
    "pryce2",
    "sabrina1",
    "sabrina2",
    "whitney",
    "will1",
    "will2",
    "ash",
    "wes",
    "rocket_M",
    "rocket_F",
    "gardenia",
    "plushbanshee",
    "sapphire",
    "starbutterfarts"
]
const PLAYER_MODEL_WALK_TEXTURES := [
    preload("res://assets/source_exact/player/red/walking.png"),
    preload("res://assets/source_exact/player/leaf-walking.png"),
    preload("res://assets/source_exact/player/gold-walking.png"),
    preload("res://assets/source_exact/player/kris-walking.png"),
    preload("res://assets/source_exact/player/brendan-walking.png"),
    preload("res://assets/source_exact/player/may-walking.png"),
    preload("res://assets/source_exact/player/hilbert-walking.png"),
    preload("res://assets/source_exact/player/hilda-walking.png"),
    preload("res://assets/source_exact/player/rosa-walking.png"),
    preload("res://assets/source_exact/player/calem-walking.png"),
    preload("res://assets/source_exact/player/serena-walking.png"),
    preload("res://assets/source_exact/player/chase-walking.png"),
    preload("res://assets/source_exact/player/elaine-walking.png"),
    preload("res://assets/source_exact/player/gloria-walking.png"),
    preload("res://assets/source_exact/player/mark-walking.png"),
    preload("res://assets/source_exact/player/mint-walking.png"),
    preload("res://assets/source_exact/player/lunick-walking.png"),
    preload("res://assets/source_exact/player/summer-walking.png"),
    preload("res://assets/source_exact/player/kellyn-walking.png"),
    preload("res://assets/source_exact/player/agatha-walking.png"),
    preload("res://assets/source_exact/player/blaine1-walking.png"),
    preload("res://assets/source_exact/player/blaine2-walking.png"),
    preload("res://assets/source_exact/player/blue-walking.png"),
    preload("res://assets/source_exact/player/brock-walking.png"),
    preload("res://assets/source_exact/player/bruno-walking.png"),
    preload("res://assets/source_exact/player/bugsy-walking.png"),
    preload("res://assets/source_exact/player/chuck-walking.png"),
    preload("res://assets/source_exact/player/clair-walking.png"),
    preload("res://assets/source_exact/player/erika-walking.png"),
    preload("res://assets/source_exact/player/falkner-walking.png"),
    preload("res://assets/source_exact/player/giovanni1-walking.png"),
    preload("res://assets/source_exact/player/giovanni2-walking.png"),
    preload("res://assets/source_exact/player/janine-walking.png"),
    preload("res://assets/source_exact/player/jasmine-walking.png"),
    preload("res://assets/source_exact/player/karen1-walking.png"),
    preload("res://assets/source_exact/player/karen2-walking.png"),
    preload("res://assets/source_exact/player/koga-walking.png"),
    preload("res://assets/source_exact/player/lance-walking.png"),
    preload("res://assets/source_exact/player/lorelei-walking.png"),
    preload("res://assets/source_exact/player/lt. surge-walking.png"),
    preload("res://assets/source_exact/player/misty1-walking.png"),
    preload("res://assets/source_exact/player/misty2-walking.png"),
    preload("res://assets/source_exact/player/morty-walking.png"),
    preload("res://assets/source_exact/player/pryce1-walking.png"),
    preload("res://assets/source_exact/player/pryce2-walking.png"),
    preload("res://assets/source_exact/player/sabrina1-walking.png"),
    preload("res://assets/source_exact/player/sabrina2-walking.png"),
    preload("res://assets/source_exact/player/whitney-walking.png"),
    preload("res://assets/source_exact/player/will1-walking.png"),
    preload("res://assets/source_exact/player/will2-walking.png"),
    preload("res://assets/source_exact/player/ash-walking.png"),
    preload("res://assets/source_exact/player/wes-walking.png"),
    preload("res://assets/source_exact/player/rocket_M-walking.png"),
    preload("res://assets/source_exact/player/rocket_F-walking.png"),
    preload("res://assets/source_exact/player/gardenia-walking.png"),
    preload("res://assets/source_exact/player/plushbanshee-walking.png"),
    preload("res://assets/source_exact/player/sapphire-walking.png"),
    preload("res://assets/source_exact/player/starbutterfarts-walking.png")
]
const PLAYER_MODEL_RUN_TEXTURES := [
    preload("res://assets/source_exact/player/red/running.png"),
    preload("res://assets/source_exact/player/leaf-running.png"),
    preload("res://assets/source_exact/player/gold-running.png"),
    preload("res://assets/source_exact/player/kris-running.png"),
    preload("res://assets/source_exact/player/brendan-running.png"),
    preload("res://assets/source_exact/player/may-running.png"),
    preload("res://assets/source_exact/player/hilbert-running.png"),
    preload("res://assets/source_exact/player/hilda-running.png"),
    preload("res://assets/source_exact/player/rosa-running.png"),
    preload("res://assets/source_exact/player/calem-running.png"),
    preload("res://assets/source_exact/player/serena-running.png"),
    preload("res://assets/source_exact/player/chase-running.png"),
    preload("res://assets/source_exact/player/elaine-running.png"),
    preload("res://assets/source_exact/player/gloria-running.png"),
    preload("res://assets/source_exact/player/mark-running.png"),
    preload("res://assets/source_exact/player/mint-running.png"),
    preload("res://assets/source_exact/player/lunick-running.png"),
    preload("res://assets/source_exact/player/summer-running.png"),
    preload("res://assets/source_exact/player/kellyn-running.png"),
    preload("res://assets/source_exact/player/agatha-running.png"),
    preload("res://assets/source_exact/player/blaine1-running.png"),
    preload("res://assets/source_exact/player/blaine2-running.png"),
    preload("res://assets/source_exact/player/blue-running.png"),
    preload("res://assets/source_exact/player/brock-running.png"),
    preload("res://assets/source_exact/player/bruno-running.png"),
    preload("res://assets/source_exact/player/bugsy-running.png"),
    preload("res://assets/source_exact/player/chuck-running.png"),
    preload("res://assets/source_exact/player/clair-running.png"),
    preload("res://assets/source_exact/player/erika-running.png"),
    preload("res://assets/source_exact/player/falkner-running.png"),
    preload("res://assets/source_exact/player/giovanni1-running.png"),
    preload("res://assets/source_exact/player/giovanni2-running.png"),
    preload("res://assets/source_exact/player/janine-running.png"),
    preload("res://assets/source_exact/player/jasmine-running.png"),
    preload("res://assets/source_exact/player/karen1-running.png"),
    preload("res://assets/source_exact/player/karen2-running.png"),
    preload("res://assets/source_exact/player/koga-running.png"),
    preload("res://assets/source_exact/player/lance-running.png"),
    preload("res://assets/source_exact/player/lorelei-running.png"),
    preload("res://assets/source_exact/player/lt. surge-running.png"),
    preload("res://assets/source_exact/player/misty1-running.png"),
    preload("res://assets/source_exact/player/misty2-running.png"),
    preload("res://assets/source_exact/player/morty-running.png"),
    preload("res://assets/source_exact/player/pryce1-running.png"),
    preload("res://assets/source_exact/player/pryce2-running.png"),
    preload("res://assets/source_exact/player/sabrina1-running.png"),
    preload("res://assets/source_exact/player/sabrina2-running.png"),
    preload("res://assets/source_exact/player/whitney-running.png"),
    preload("res://assets/source_exact/player/will1-running.png"),
    preload("res://assets/source_exact/player/will2-running.png"),
    preload("res://assets/source_exact/player/ash-running.png"),
    preload("res://assets/source_exact/player/wes-running.png"),
    preload("res://assets/source_exact/player/rocket_M-running.png"),
    preload("res://assets/source_exact/player/rocket_F-running.png"),
    preload("res://assets/source_exact/player/gardenia-running.png"),
    preload("res://assets/source_exact/player/plushbanshee-running.png"),
    preload("res://assets/source_exact/player/sapphire-running.png"),
    preload("res://assets/source_exact/player/starbutterfarts-running.png")
]
const PLAYER_MODEL_SLEEP_TEXTURES := [
    preload("res://assets/source_exact/player/red/sleepingbag.png"),
    preload("res://assets/source_exact/player/leaf-sleepingbag.png"),
    preload("res://assets/source_exact/player/gold-sleepingbag.png"),
    preload("res://assets/source_exact/player/kris-sleepingbag.png"),
    preload("res://assets/source_exact/player/brendan-sleepingbag.png"),
    preload("res://assets/source_exact/player/may-sleepingbag.png"),
    preload("res://assets/source_exact/player/hilbert-sleepingbag.png"),
    preload("res://assets/source_exact/player/hilda-sleepingbag.png"),
    preload("res://assets/source_exact/player/rosa-sleepingbag.png"),
    preload("res://assets/source_exact/player/calem-sleepingbag.png"),
    preload("res://assets/source_exact/player/serena-sleepingbag.png"),
    preload("res://assets/source_exact/player/chase-sleepingbag.png"),
    preload("res://assets/source_exact/player/elaine-sleepingbag.png"),
    preload("res://assets/source_exact/player/gloria-sleepingbag.png"),
    preload("res://assets/source_exact/player/mark-sleepingbag.png"),
    preload("res://assets/source_exact/player/mint-sleepingbag.png"),
    preload("res://assets/source_exact/player/lunick-sleepingbag.png"),
    preload("res://assets/source_exact/player/summer-sleepingbag.png"),
    preload("res://assets/source_exact/player/kellyn-sleepingbag.png"),
    preload("res://assets/source_exact/player/agatha-sleepingbag.png"),
    preload("res://assets/source_exact/player/blaine1-sleepingbag.png"),
    preload("res://assets/source_exact/player/blaine2-sleepingbag.png"),
    preload("res://assets/source_exact/player/blue-sleepingbag.png"),
    preload("res://assets/source_exact/player/brock-sleepingbag.png"),
    preload("res://assets/source_exact/player/bruno-sleepingbag.png"),
    preload("res://assets/source_exact/player/bugsy-sleepingbag.png"),
    preload("res://assets/source_exact/player/chuck-sleepingbag.png"),
    preload("res://assets/source_exact/player/clair-sleepingbag.png"),
    preload("res://assets/source_exact/player/erika-sleepingbag.png"),
    preload("res://assets/source_exact/player/falkner-sleepingbag.png"),
    preload("res://assets/source_exact/player/giovanni1-sleepingbag.png"),
    preload("res://assets/source_exact/player/giovanni2-sleepingbag.png"),
    preload("res://assets/source_exact/player/janine-sleepingbag.png"),
    preload("res://assets/source_exact/player/jasmine-sleepingbag.png"),
    preload("res://assets/source_exact/player/karen1-sleepingbag.png"),
    preload("res://assets/source_exact/player/karen2-sleepingbag.png"),
    preload("res://assets/source_exact/player/koga-sleepingbag.png"),
    preload("res://assets/source_exact/player/lance-sleepingbag.png"),
    preload("res://assets/source_exact/player/lorelei-sleepingbag.png"),
    preload("res://assets/source_exact/player/lt. surge-sleepingbag.png"),
    preload("res://assets/source_exact/player/misty1-sleepingbag.png"),
    preload("res://assets/source_exact/player/misty2-sleepingbag.png"),
    preload("res://assets/source_exact/player/morty-sleepingbag.png"),
    preload("res://assets/source_exact/player/pryce1-sleepingbag.png"),
    preload("res://assets/source_exact/player/pryce2-sleepingbag.png"),
    preload("res://assets/source_exact/player/sabrina1-sleepingbag.png"),
    preload("res://assets/source_exact/player/sabrina2-sleepingbag.png"),
    preload("res://assets/source_exact/player/whitney-sleepingbag.png"),
    preload("res://assets/source_exact/player/will1-sleepingbag.png"),
    preload("res://assets/source_exact/player/will2-sleepingbag.png"),
    preload("res://assets/source_exact/player/ash-sleepingbag.png"),
    preload("res://assets/source_exact/player/wes-sleepingbag.png"),
    preload("res://assets/source_exact/player/rocket_M-sleepingbag.png"),
    preload("res://assets/source_exact/player/rocket_F-sleepingbag.png"),
    preload("res://assets/source_exact/player/gardenia-sleepingbag.png"),
    preload("res://assets/source_exact/player/plushbanshee-sleepingbag.png"),
    preload("res://assets/source_exact/player/sapphire-sleepingbag.png"),
    preload("res://assets/source_exact/player/starbutterfarts-sleepingbag.png")
]
const PLAYER_MODEL_SITTING_TEXTURES := [
    preload("res://assets/source_exact/player/red/sitting.png"),
    preload("res://assets/source_exact/player/leaf-sitting.png"),
    preload("res://assets/source_exact/player/gold-sitting.png"),
    preload("res://assets/source_exact/player/kris-sitting.png"),
    preload("res://assets/source_exact/player/brendan-sitting.png"),
    preload("res://assets/source_exact/player/may-sitting.png"),
    preload("res://assets/source_exact/player/hilbert-sitting.png"),
    preload("res://assets/source_exact/player/hilda-sitting.png"),
    preload("res://assets/source_exact/player/rosa-sitting.png"),
    preload("res://assets/source_exact/player/calem-sitting.png"),
    preload("res://assets/source_exact/player/serena-sitting.png"),
    preload("res://assets/source_exact/player/chase-sitting.png"),
    preload("res://assets/source_exact/player/elaine-sitting.png"),
    preload("res://assets/source_exact/player/gloria-sitting.png"),
    preload("res://assets/source_exact/player/mark-sitting.png"),
    preload("res://assets/source_exact/player/mint-sitting.png"),
    preload("res://assets/source_exact/player/lunick-sitting.png"),
    preload("res://assets/source_exact/player/summer-sitting.png"),
    preload("res://assets/source_exact/player/kellyn-sitting.png"),
    preload("res://assets/source_exact/player/agatha-sitting.png"),
    preload("res://assets/source_exact/player/blaine1-sitting.png"),
    preload("res://assets/source_exact/player/blaine2-sitting.png"),
    preload("res://assets/source_exact/player/blue-sitting.png"),
    preload("res://assets/source_exact/player/brock-sitting.png"),
    preload("res://assets/source_exact/player/bruno-sitting.png"),
    preload("res://assets/source_exact/player/bugsy-sitting.png"),
    preload("res://assets/source_exact/player/chuck-sitting.png"),
    preload("res://assets/source_exact/player/clair-sitting.png"),
    preload("res://assets/source_exact/player/erika-sitting.png"),
    preload("res://assets/source_exact/player/falkner-sitting.png"),
    preload("res://assets/source_exact/player/giovanni1-sitting.png"),
    preload("res://assets/source_exact/player/giovanni2-sitting.png"),
    preload("res://assets/source_exact/player/janine-sitting.png"),
    preload("res://assets/source_exact/player/jasmine-sitting.png"),
    preload("res://assets/source_exact/player/karen1-sitting.png"),
    preload("res://assets/source_exact/player/karen2-sitting.png"),
    preload("res://assets/source_exact/player/koga-sitting.png"),
    preload("res://assets/source_exact/player/lance-sitting.png"),
    preload("res://assets/source_exact/player/lorelei-sitting.png"),
    preload("res://assets/source_exact/player/lt. surge-sitting.png"),
    preload("res://assets/source_exact/player/misty1-sitting.png"),
    preload("res://assets/source_exact/player/misty2-sitting.png"),
    preload("res://assets/source_exact/player/morty-sitting.png"),
    preload("res://assets/source_exact/player/pryce1-sitting.png"),
    preload("res://assets/source_exact/player/pryce2-sitting.png"),
    preload("res://assets/source_exact/player/sabrina1-sitting.png"),
    preload("res://assets/source_exact/player/sabrina2-sitting.png"),
    preload("res://assets/source_exact/player/whitney-sitting.png"),
    preload("res://assets/source_exact/player/will1-sitting.png"),
    preload("res://assets/source_exact/player/will2-sitting.png"),
    preload("res://assets/source_exact/player/ash-sitting.png"),
    preload("res://assets/source_exact/player/wes-sitting.png"),
    preload("res://assets/source_exact/player/rocket_M-sitting.png"),
    preload("res://assets/source_exact/player/rocket_F-sitting.png"),
    preload("res://assets/source_exact/player/gardenia-sitting.png"),
    preload("res://assets/source_exact/player/plushbanshee-sitting.png"),
    preload("res://assets/source_exact/player/sapphire-sitting.png"),
    preload("res://assets/source_exact/player/starbutterfarts-sitting.png")
]
const PLAYER_MODEL_BATTLE_BACK_TEXTURES := [
    preload("res://assets/source_exact/player/red/back.png"),
    preload("res://assets/source_exact/player/leaf-back.png"),
    preload("res://assets/source_exact/player/gold-back.png"),
    preload("res://assets/source_exact/player/kris-back.png"),
    preload("res://assets/source_exact/player/brendan-back.png"),
    preload("res://assets/source_exact/player/may-back.png"),
    preload("res://assets/source_exact/player/hilbert-back.png"),
    preload("res://assets/source_exact/player/hilda-back.png"),
    preload("res://assets/source_exact/player/rosa-back.png"),
    preload("res://assets/source_exact/player/calem-back.png"),
    preload("res://assets/source_exact/player/serena-back.png"),
    preload("res://assets/source_exact/player/chase-back.png"),
    preload("res://assets/source_exact/player/elaine-back.png"),
    preload("res://assets/source_exact/player/gloria-back.png"),
    preload("res://assets/source_exact/player/mark-back.png"),
    preload("res://assets/source_exact/player/mint-back.png"),
    preload("res://assets/source_exact/player/lunick-back.png"),
    preload("res://assets/source_exact/player/summer-back.png"),
    preload("res://assets/source_exact/player/kellyn-back.png"),
    preload("res://assets/source_exact/player/agatha-back.png"),
    preload("res://assets/source_exact/player/blaine1-back.png"),
    preload("res://assets/source_exact/player/blaine2-back.png"),
    preload("res://assets/source_exact/player/blue-back.png"),
    preload("res://assets/source_exact/player/brock-back.png"),
    preload("res://assets/source_exact/player/bruno-back.png"),
    preload("res://assets/source_exact/player/bugsy-back.png"),
    preload("res://assets/source_exact/player/chuck-back.png"),
    preload("res://assets/source_exact/player/clair-back.png"),
    preload("res://assets/source_exact/player/erika-back.png"),
    preload("res://assets/source_exact/player/falkner-back.png"),
    preload("res://assets/source_exact/player/giovanni1-back.png"),
    preload("res://assets/source_exact/player/giovanni2-back.png"),
    preload("res://assets/source_exact/player/janine-back.png"),
    preload("res://assets/source_exact/player/jasmine-back.png"),
    preload("res://assets/source_exact/player/karen1-back.png"),
    preload("res://assets/source_exact/player/karen2-back.png"),
    preload("res://assets/source_exact/player/koga-back.png"),
    preload("res://assets/source_exact/player/lance-back.png"),
    preload("res://assets/source_exact/player/lorelei-back.png"),
    preload("res://assets/source_exact/player/lt. surge-back.png"),
    preload("res://assets/source_exact/player/misty1-back.png"),
    preload("res://assets/source_exact/player/misty2-back.png"),
    preload("res://assets/source_exact/player/morty-back.png"),
    preload("res://assets/source_exact/player/pryce1-back.png"),
    preload("res://assets/source_exact/player/pryce2-back.png"),
    preload("res://assets/source_exact/player/sabrina1-back.png"),
    preload("res://assets/source_exact/player/sabrina2-back.png"),
    preload("res://assets/source_exact/player/whitney-back.png"),
    preload("res://assets/source_exact/player/will1-back.png"),
    preload("res://assets/source_exact/player/will2-back.png"),
    preload("res://assets/source_exact/player/ash-back.png"),
    preload("res://assets/source_exact/player/wes-back.png"),
    preload("res://assets/source_exact/player/rocket_M-back.png"),
    preload("res://assets/source_exact/player/rocket_F-back.png"),
    preload("res://assets/source_exact/player/gardenia-back.png"),
    preload("res://assets/source_exact/player/plushbanshee-back.png"),
    preload("res://assets/source_exact/player/sapphire-back.png"),
    preload("res://assets/source_exact/player/starbutterfarts-back.png")
]
const PLAYER_MODEL_REPLACE_COLORS := [
    Color(0.972549, 0.219608, 0.031373, 1.0), # red mod
    Color(0.313725, 0.282353, 0.972549, 1.0), # leaf
    Color(0.972549, 0.219608, 0.031373, 1.0), # gold
    Color(0.313725, 0.282353, 0.972549, 1.0), # kris
    Color(0.972549, 0.219608, 0.031373, 1.0), # brendan
    Color(0.313725, 0.282353, 0.972549, 1.0), # may
    Color(0.972549, 0.219608, 0.031373, 1.0), # hilbert
    Color(0.313725, 0.282353, 0.972549, 1.0), # hilda
    Color(0.313725, 0.282353, 0.972549, 1.0), # rosa
    Color(0.313725, 0.282353, 0.972549, 1.0), # calem
    Color(0.972549, 0.219608, 0.031373, 1.0), # serena
    Color(0.972549, 0.219608, 0.031373, 1.0), # chase
    Color(0.313725, 0.282353, 0.972549, 1.0), # elaine
    Color(0.972549, 0.219608, 0.031373, 1.0), # gloria
    Color(0.972549, 0.219608, 0.031373, 1.0), # mark
    Color(0.313725, 0.282353, 0.972549, 1.0), # mint
    Color(0.349020, 0.282353, 1.0, 1.0), # lunick
    Color(0.972549, 0.219608, 0.031373, 1.0), # summer
    Color(0.964706, 0.031373, 0.003922, 1.0),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(56,56,112),
    Color8(248,56,8),
    Color8(248,56,8),
    Color8(216,136,48),
    Color8(150,105,25),
    Color8(121,129,42),
    Color8(249,230,130)
]
const PLAYER_MODEL_BATTLE_REPLACE_COLORS := [
    Color8(176, 72, 40, 255), # red
    Color8(56, 40, 248, 255), # leaf
    Color8(176, 72, 40, 255), # gold
    Color8(56, 40, 248, 255), # kris
    Color8(176, 72, 40, 255), # brendan
    Color8(176, 72, 40, 255), # may
    Color8(88, 96, 184, 255), # hilbert
    Color8(155, 58, 48, 255), # hilda
    Color8(80, 72, 64, 255), # rosa
    Color8(54, 83, 197, 255), # calem
    Color8(222, 42, 42, 255), # serena
    Color8(176, 72, 40, 255), # chase
    Color8(56, 40, 248, 255), # elaine
    Color8(55, 134, 110, 255), # gloria
    Color8(232, 79, 79, 255), # mark
    Color8(41, 107, 210, 255), # mint
    Color8(198, 57, 74, 255), # lunick
    Color8(232, 79, 79, 255), # summer
    Color8(232, 79, 79, 255),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(56,56,112),
    Color8(176,72,40),
    Color8(176,72,40),
    Color8(216,136,48),
    Color8(150,105,25),
    Color8(121,129,42),
    Color8(249,230,130)
]
const GENERATION_TIP_SECONDS := 5.0
const POKEMON_EGG_TEXTURE := preload("res://assets/pokemon_egg.png")
const TRAINER_BATTLE_TEXTURE := preload("res://assets/trainer_battle_reference.png")
const GHOST_BATTLE_SHEET := preload("res://assets/events/ghost_battle_front.png")
const ITEM_BAG_POCKET_TEXTURE := preload("res://assets/item_bag_pockets.png")
const SOURCE_BATTLE_INTRO_TEXTURE := preload(
    "res://assets/source_exact/battle/battle_intro_anim1_sheet1.png")
const SOURCE_POKEBALL_TEXTURE := preload(
    "res://assets/source_exact/global/pokeball1_color.png")
const SOURCE_CAPTURE_POOF: Texture2D = preload(
    "res://assets/source_exact/global/poof_sheet1.png")
const SOURCE_POKEBALL_WIGGLE_TEXTURE := preload(
    "res://assets/source_exact/global/pokeball_wiggleSheet1_color.png")
const SOURCE_EVOLUTION_BACKGROUND := preload(
    "res://assets/source_exact/battle/battle_bg3.png")
const SOURCE_HATCH_BACKGROUND := preload(
    "res://assets/source_exact/battle/intro_frame6.png")
const SOURCE_LEVEL_STATS_BACKGROUND := preload(
    "res://assets/source_exact/battle/gsc/levelup_stats_screen1.png")
const SOURCE_ATTACK_MENU_BACKGROUND := preload(
    "res://assets/source_exact/menu/attack_screen1.png")
const SOURCE_PARTY_BACKGROUND := preload(
    "res://assets/source_exact/menu/gsc/background1.png")
const SOURCE_PARTY_HEALTH_ROW := preload(
    "res://assets/source_exact/menu/gsc/health_bar1.png")
const SOURCE_STATS_BACKGROUNDS := [
    preload("res://assets/source_exact/menu/stats_screen1.png"),
    preload("res://assets/source_exact/menu/stats_screen2.png"),
    preload("res://assets/source_exact/menu/stats_screen3.png")
]
const UNOWN_FONT := preload("res://assets/source_exact/global/unown_font.fnt")
const JOHTO_FONT := preload("res://assets/source_text_font.fnt")
const SYMBOL_FONT := preload("res://assets/fonts.ttf")
const DIALOGUE_BORDER := preload("res://assets/pokewilds_dialogue_border.png")
const SOURCE_SOUND_ROOT := "res://assets/source_audio/sounds/"
const EXP_GAIN_AUDIO_PATH := SOURCE_SOUND_ROOT + "xp-gain1.ogg"
const LEVEL_UP_AUDIO_PATH := SOURCE_SOUND_ROOT + "xp-levelup1.ogg"
const SOURCE_FRAME_TIME := 1.0 / 60.0
const BATTLE_ENTRY_SLIDE_PX_PER_FRAME: float = 4.0
const SOURCE_EXP_UNITS := 68
const SOURCE_LEVEL_STATS_MIN_FRAMES := 82
const SOURCE_EVOLUTION_CANCEL_END_FRAME := 464
const SOURCE_HATCH_COMPLETE_FRAME := 588
const BATTLE_TEXT_CHAR_DELAY := 0.05
const MESSAGE_HOLD_SECONDS := 1.2
const ITEM_MENU_VISIBLE_ROWS := 5
const EGG_HATCH_STEPS := 20 * PokemonEcology.EGG_STEP_INTERVAL
const STARTING_INVENTORY := {
    "POTION":0,
    "SLEEPING BAG":1,
    "ESCAPE ROPE":1
}

const POKEMON_TEXTURES := {
    "pidgey": preload("res://assets/pokemon_pidgey.png"),
    "rattata": preload("res://assets/pokemon_rattata.png"),
    "caterpie": preload("res://assets/pokemon_caterpie.png"),
    "pikachu": preload("res://assets/pokemon_pikachu.png"),
    "machop": preload("res://assets/pokemon_machop.png")
}

const BATTLE_BALL_BONUS := {
    "POKE BALL":1.0, "GREAT BALL":1.5, "ULTRA BALL":2.0,
    "HEAVY BALL":1.5, "LURE BALL":1.0, "FRIEND BALL":1.0,
    "LOVE BALL":1.0, "LEVEL BALL":1.0, "FAST BALL":1.0,
    "MOON BALL":1.0, "DUSK BALL":1.0, "NET BALL":1.0,
    "DIVE BALL":1.0, "QUICK BALL":1.0, "HEAL BALL":1.0,
    "NEST BALL":1.0, "DREAM BALL":1.0, "TIMER BALL":1.0,
    "MASTER BALL":999.0, "PARK BALL":999.0
}

const BATTLE_ITEM_RULES := {
    "POTION":{"kind":"heal", "amount":20},
    "SUPER POTION":{"kind":"heal", "amount":50},
    "HYPER POTION":{"kind":"heal", "amount":200},
    "MAX POTION":{"kind":"heal", "amount":99999},
    "FULL RESTORE":{"kind":"full_restore", "amount":99999},
    "RAGECANDYBAR":{"kind":"heal", "amount":20},
    "FULL HEAL":{"kind":"status", "status":"ANY"},
    "ANTIDOTE":{"kind":"status", "status":"POISON"},
    "BURN HEAL":{"kind":"status", "status":"BURN"},
    "ICE HEAL":{"kind":"status", "status":"FREEZE"},
    "AWAKENING":{"kind":"status", "status":"SLEEP"},
    "PARLYZ HEAL":{"kind":"status", "status":"PARALYSIS"},
    "LUM BERRY":{"kind":"status", "status":"ANY"},
    "PECHA BERRY":{"kind":"status", "status":"POISON"},
    "CHERI BERRY":{"kind":"status", "status":"PARALYSIS"},
    "ASPEAR BERRY":{"kind":"status", "status":"FREEZE"},
    "CHESTO BERRY":{"kind":"status", "status":"SLEEP"},
    "RAWST BERRY":{"kind":"status", "status":"BURN"},
    "PERSIM BERRY":{"kind":"confusion"},
    "BERRY JUICE":{"kind":"heal", "amount":20},
    "MOOMOO MILK":{"kind":"heal", "amount":100},
    "REVIVE":{"kind":"revive", "fraction":0.5},
    "MAX REVIVE":{"kind":"revive", "fraction":1.0}
}

var sign_dialog: ConfirmationDialog
var sign_edit: LineEdit
var sign_edit_cell := Vector2i.ZERO
var sign_edit_mode := "SIGN"

@onready var setup_panel: Control = $UI/SetupPanel
@onready var world: Node2D = $World
@onready var touch_controls: TouchControls = $UI/TouchControls
@onready var touch_config: Panel = $UI/TouchConfig

@onready var player_model_name: Label = $UI/SetupPanel/PlayerModelName
@onready var world_edit: LineEdit = $UI/SetupPanel/WorldEdit
@onready var start_button: Button = $UI/SetupPanel/StartButton
@onready var menu_status: Label = $UI/SetupPanel/Status
@onready var player_preview: Sprite2D = $UI/SetupPanel/PlayerPreview
@onready var player_color_swatch: TextureRect = $UI/SetupPanel/PlayerColorSwatch

@onready var generation_panel: Control = $UI/GenerationPanel
@onready var generation_status: Label = $UI/GenerationPanel/Status
@onready var generation_tip_title: Label = $UI/GenerationPanel/ControlsTitle
@onready var generation_tip_text: Label = $UI/GenerationPanel/Controls

@onready var message_panel: Panel = $UI/MessagePanel
@onready var message_label: Label = $UI/MessagePanel/Message

@onready var battle_panel: Control = $UI/BattlePanel
@onready var battle_transition: ColorRect = $UI/BattlePanel/Transition
@onready var source_command_frame: TextureRect = $UI/BattlePanel/ExactBattleCommandFrame
@onready var source_single_hud: Control = $UI/BattlePanel/SourceSingleHud
@onready var source_enemy_name: Label = $UI/BattlePanel/SourceSingleHud/EnemyName
@onready var source_enemy_level: Label = $UI/BattlePanel/SourceSingleHud/EnemyLevel
@onready var source_enemy_status: Label = $UI/BattlePanel/SourceSingleHud/EnemyStatus
@onready var source_enemy_gender: TextureRect = $UI/BattlePanel/SourceSingleHud/EnemyGender
@onready var source_enemy_hp_fill: ColorRect = $UI/BattlePanel/SourceSingleHud/EnemyHPFill
@onready var source_player_name: Label = $UI/BattlePanel/SourceSingleHud/PlayerName
@onready var source_player_level: Label = $UI/BattlePanel/SourceSingleHud/PlayerLevel
@onready var source_player_status: Label = $UI/BattlePanel/SourceSingleHud/PlayerStatus
@onready var source_player_gender: TextureRect = $UI/BattlePanel/SourceSingleHud/PlayerGender
@onready var source_player_hp_fill: ColorRect = $UI/BattlePanel/SourceSingleHud/PlayerHPFill
@onready var source_player_hp_current: Label = $UI/BattlePanel/SourceSingleHud/PlayerHPCurrent
@onready var source_player_hp_max: Label = $UI/BattlePanel/SourceSingleHud/PlayerHPMax
@onready var source_player_exp_fill: ColorRect = $UI/BattlePanel/SourceSingleHud/EXPFill
@onready var source_command_cursor: TextureRect = $UI/BattlePanel/SourceSingleHud/SourceCommandCursor
@onready var player_battle_sprite: TextureRect = $UI/BattlePanel/PlayerSprite
@onready var enemy_sprite: TextureRect = $UI/BattlePanel/EnemySprite
@onready var player_partner_sprite: TextureRect = $UI/BattlePanel/PlayerPartnerSprite
@onready var enemy_partner_sprite: TextureRect = $UI/BattlePanel/EnemyPartnerSprite
@onready var double_status: Label = $UI/BattlePanel/DoubleStatus
@onready var battle_weather_overlay: ColorRect = $UI/BattlePanel/WeatherOverlay
@onready var battle_move_animation: TextureRect = $UI/BattlePanel/MoveAnimation
@onready var battle_field_label: Label = $UI/BattlePanel/FieldLabel
@onready var enemy_hud: Control = $UI/BattlePanel/EnemyHud
@onready var enemy_label: Label = $UI/BattlePanel/EnemyHud/EnemyLabel
@onready var enemy_level_label: Label = $UI/BattlePanel/EnemyHud/Level
@onready var enemy_gender_label: Label = $UI/BattlePanel/EnemyHud/Gender
@onready var enemy_hp_fill: ColorRect = $UI/BattlePanel/EnemyHud/HPFill
@onready var player_hud: Control = $UI/BattlePanel/PlayerHud
@onready var player_battle_label: Label = $UI/BattlePanel/PlayerHud/Name
@onready var player_level_label: Label = $UI/BattlePanel/PlayerHud/Level
@onready var player_gender_label: Label = $UI/BattlePanel/PlayerHud/Gender
@onready var player_hp_fill: ColorRect = $UI/BattlePanel/PlayerHud/HPFill
@onready var player_hp_value: Label = $UI/BattlePanel/PlayerHud/HPValue
@onready var player_exp_fill: ColorRect = $UI/BattlePanel/PlayerHud/EXPFill
@onready var battle_status: Label = $UI/BattlePanel/BattleStatus
@onready var battle_command_box: Panel = $UI/BattlePanel/CommandBox
@onready var battle_command_divider: ColorRect = $UI/BattlePanel/CommandBox/Divider
@onready var battle_actions: Control = $UI/BattlePanel/Actions
@onready var battle_message_arrow: Label = $UI/BattlePanel/MessageArrow
@onready var fight_button: Button = $UI/BattlePanel/Actions/Fight
@onready var item_button: Button = $UI/BattlePanel/Actions/Item
@onready var party_button: Button = $UI/BattlePanel/Actions/Party
@onready var catch_button: Button = $UI/BattlePanel/Actions/Catch
@onready var run_button: Button = $UI/BattlePanel/Actions/Run
@onready var battle_command_cursor: Label = $UI/BattlePanel/Actions/Cursor
@onready var battle_move_type_box: Panel = $UI/BattlePanel/MoveTypeBox
@onready var battle_move_type: Label = $UI/BattlePanel/MoveTypeBox/Type
@onready var battle_move_pp: Label = $UI/BattlePanel/MoveTypeBox/PP
@onready var battle_move_box: Panel = $UI/BattlePanel/MoveBox
@onready var battle_move_cursor: Label = $UI/BattlePanel/MoveBox/Cursor
@onready var battle_move_list: Label = $UI/BattlePanel/MoveBox/List
@onready var battle_audio: AudioStreamPlayer = $UI/BattlePanel/BattleAudio
@onready var battle_submenu: Control = $UI/BattlePanel/BattleSubmenu
@onready var battle_submenu_title: Label = $UI/BattlePanel/BattleSubmenu/Window/Title
@onready var battle_submenu_cursor: Label = $UI/BattlePanel/BattleSubmenu/Window/Cursor
@onready var battle_submenu_list: Label = $UI/BattlePanel/BattleSubmenu/Window/List
@onready var battle_submenu_hint: Label = $UI/BattlePanel/BattleSubmenu/Window/Hint

@onready var progression_overlay: Control = $UI/ProgressionOverlay
@onready var progression_background: TextureRect = $UI/ProgressionOverlay/Background
@onready var progression_animation: TextureRect = $UI/ProgressionOverlay/Animation
@onready var progression_sprite_top: TextureRect = $UI/ProgressionOverlay/SpriteTop
@onready var progression_sprite_bottom: TextureRect = $UI/ProgressionOverlay/SpriteBottom
@onready var progression_title: Label = $UI/ProgressionOverlay/Title
@onready var progression_list: Label = $UI/ProgressionOverlay/List
@onready var progression_values: Label = $UI/ProgressionOverlay/Values
@onready var progression_cursor: Label = $UI/ProgressionOverlay/Cursor
@onready var progression_detail: Label = $UI/ProgressionOverlay/Detail
@onready var progression_hint: Label = $UI/ProgressionOverlay/Hint

@onready var show_touch: CheckButton = $UI/TouchConfig/VBox/ShowTouch
@onready var auto_hide: CheckButton = $UI/TouchConfig/VBox/AutoHide
@onready var touch_opacity_label: Label = $UI/TouchConfig/VBox/OpacityLabel
@onready var touch_opacity_slider: HSlider = $UI/TouchConfig/VBox/Opacity
@onready var touch_size_label: Label = $UI/TouchConfig/VBox/SizeLabel
@onready var touch_size_slider: HSlider = $UI/TouchConfig/VBox/Size
@onready var touch_theme_button: Button = $UI/TouchConfig/VBox/ThemeMode

@onready var game_menu: Control = $UI/GameMenu
@onready var game_menu_box: Panel = $UI/GameMenu/MenuBox
@onready var game_menu_cursor: Label = $UI/GameMenu/MenuBox/Cursor
@onready var game_menu_detail: Panel = $UI/GameMenu/DetailBox
@onready var game_menu_detail_title: Label = $UI/GameMenu/DetailBox/Title
@onready var game_menu_detail_body: Label = $UI/GameMenu/DetailBox/Body
@onready var game_menu_map_screen: Control = $UI/GameMenu/MapScreen
@onready var game_menu_map: Control = $UI/GameMenu/MapScreen/MapCanvas
@onready var guide_menu: Panel = $UI/GameMenu/GuideMenu
@onready var guide_menu_cursor: Label = $UI/GameMenu/GuideMenu/Cursor
@onready var guide_menu_up_arrow: Label = $UI/GameMenu/GuideMenu/UpArrow
@onready var guide_menu_down_arrow: Label = $UI/GameMenu/GuideMenu/DownArrow
@onready var guide_menu_rows: Array[Label] = [
    $UI/GameMenu/GuideMenu/FieldMoves,
    $UI/GameMenu/GuideMenu/Crafting,
    $UI/GameMenu/GuideMenu/Fainting,
    $UI/GameMenu/GuideMenu/Ghosts
]
@onready var item_pocket_menu: Control = $UI/GameMenu/ItemPocketMenu
@onready var item_pocket_label: TextureRect = $UI/GameMenu/ItemPocketMenu/PocketLabel
@onready var item_pocket_bag: TextureRect = $UI/GameMenu/ItemPocketMenu/PocketBag
@onready var item_pocket_cursor: Control = $UI/GameMenu/ItemPocketMenu/Cursor
@onready var item_pocket_list: Label = $UI/GameMenu/ItemPocketMenu/List
@onready var item_pocket_quantities: Label = $UI/GameMenu/ItemPocketMenu/Quantities
@onready var item_pocket_description: Label = $UI/GameMenu/ItemPocketMenu/Description
@onready var pokemon_menu: Control = $UI/GameMenu/PokemonMenu
@onready var pokemon_menu_cursor: Label = $UI/GameMenu/PokemonMenu/Cursor
@onready var pokemon_menu_sprite: TextureRect = $UI/GameMenu/PokemonMenu/PokemonSprite
@onready var pokemon_menu_name: Label = $UI/GameMenu/PokemonMenu/Name
@onready var pokemon_menu_level: Label = $UI/GameMenu/PokemonMenu/Level
@onready var pokemon_menu_hp_value: Label = $UI/GameMenu/PokemonMenu/HPValue
@onready var pokemon_menu_hp_fill: ColorRect = $UI/GameMenu/PokemonMenu/HPBar/Fill
@onready var pokemon_menu_prompt: Label = $UI/GameMenu/PokemonMenu/PromptBox/Prompt
@onready var save_confirm: Panel = $UI/GameMenu/SaveConfirm
@onready var save_confirm_cursor: Label = $UI/GameMenu/SaveConfirm/Cursor
@onready var quit_prompt: Panel = $UI/QuitPrompt
@onready var quit_prompt_title: Label = $UI/QuitPrompt/Title
@onready var quit_prompt_cursor: Label = $UI/QuitPrompt/Cursor
@onready var crafting_panel: Panel = $UI/CraftingPanel
@onready var crafting_title: Label = $UI/CraftingPanel/Title
@onready var crafting_cursor: Label = $UI/CraftingPanel/Cursor
@onready var crafting_list: Label = $UI/CraftingPanel/List
@onready var crafting_cost: RichTextLabel = $UI/CraftingPanel/Cost
@onready var build_panel: Panel = $UI/BuildPanel
@onready var build_title: Label = $UI/BuildPanel/Title
@onready var build_builder: Label = $UI/BuildPanel/Builder
@onready var build_cursor: Label = $UI/BuildPanel/Cursor
@onready var build_list: Label = $UI/BuildPanel/List
@onready var build_cost: RichTextLabel = $UI/BuildPanel/Cost
@onready var resource_popup: Panel = $UI/ResourcePopup
@onready var resource_popup_text: Label = $UI/ResourcePopup/Text

var started := false
var generating := false
var generation_tip_timer := 0.0
var generation_tip_index := -1
var battle_active := false
var battle_turn_busy := false
var battle_player: Dictionary = {}
var battle_enemy: Dictionary = {}
var battle_context: Dictionary = {}
var battle_enemy_party: Array = []
var battle_enemy_party_index := 0
var battle_enemy_action_count := 0
var battle_is_double := false
var battle_player_partner: Dictionary = {}
var battle_enemy_partner: Dictionary = {}
var battle_partner_party_index := -1
var battle_enemy_partner_party_index := -1
var battle_double_command_slot := 0
var battle_double_actions: Array[Dictionary] = []
var battle_double_pending_move := ""
var battle_double_replacement_slot := -1
var battle_result_sent := false
var battle_party_index := 0
var battle_move_index := 0
var battle_command_index := 0
var battle_ui_mode := "INTRO"
var battle_rng := RandomNumberGenerator.new()
var battle_run_attempts := 0
var battle_turn_count := 0
var battle_field: Dictionary = {}
var battle_submenu_mode := ""
var battle_submenu_index := 0
var battle_submenu_entries: Array[Dictionary] = []
var battle_pending_item := ""
var last_battle_ball := ""
var battle_item_pocket_open := false
var battle_item_pocket_index := ItemData.POCKET_ITEMS
var battle_item_menu_names: Array[String] = []
var battle_item_menu_index := 0
var source_effect_playing := false
var source_boss: Control
var source_boss_action_count := 0
var source_boss_damage_finished := true
var source_boss_move_type := "NORMAL"
var source_mewtwo: Control
var source_mewtwo_intro_seen := false
var battle_animation_manifest: Dictionary = {}
var battle_animation_cache: Dictionary = {}
var battle_sprite_alpha_cache: Dictionary = {}
var battle_sprite_animation_elapsed := 0.0
var battle_sprite_animation_frame := 0
const BATTLE_SPRITE_FRAME_SECONDS := 0.18
var battle_player_cry_played := false
var battle_capture_ball: TextureRect = null
var battle_text_full := ""
var battle_text_busy := false
var battle_text_accumulator := 0.0
var mansion_switch_open := false
var mansion_switch_stage := 0
var mansion_switch_index := 0
var battle_entry_pending := false
var progression_move_frame: Panel
var progression_type_frame: Panel
var progression_choice_frame: Panel
var progression_move_rows: Array[Label] = []
var progression_type_label: Label
var progression_pp_label: Label
var progression_menu_cursor: Label
var progression_yes_no_cursor: Label
var overworld_evolution_item := ""
var overworld_evolution_running := false
var capture_experience_presenting := false
var progression_active := false
var progression_mode := ""
var hatch_skip_requested := false
const HATCH_PLAYBACK_SPEED := 1.2
var progression_waiting_input := false
var progression_choice_index := 0
var progression_pending_move := ""
var progression_pokemon: Dictionary = {}
var progression_level_dialogue: Panel
var progression_level_message: Label
var setup_load_panel: Control
var setup_load_name: Label
var setup_load_index := 0
var setup_load_entries: Array[Dictionary] = []
var setup_load_open := false
var setup_load_committed := false
var setup_load_path := ""
var pokemon_action_panel: Panel
var pokemon_action_cursor: TextureRect
var pokemon_action_list: Label
var pokemon_menu_gender: TextureRect
var pokemon_action_open := false
var pokemon_action_index := 0
var pokemon_action_entries: Array[String] = []
var pokemon_switch_selecting := false
var pokemon_switch_source_index := -1
var setup_go_cursor: TextureRect
var pokemon_party_rows: Array[Dictionary] = []
var party_sprite_animation_elapsed := 0.0
var party_sprite_animation_frame := 0
var pokemon_stats_pages: Array[Control] = []
var pokemon_stats_tabs: Array[ColorRect] = []
var pokemon_stats_tab_ticks: Array[Label] = []
var pokemon_stats_fields: Dictionary = {}
var pokemon_stats_exp_fill: ColorRect
var progression_stats_frame: Panel
var progression_stats_fields: Array[Label] = []
var pokemon_stats_overlay: Control
var pokemon_stats_background: TextureRect
var pokemon_stats_sprite: TextureRect
var pokemon_stats_header_left: Label
var pokemon_stats_header_right: Label
var pokemon_stats_shiny: TextureRect
var pokemon_stats_gender: TextureRect
var pokemon_stats_body_left: Label
var pokemon_stats_body_right: Label
var pokemon_stats_hp_fill: ColorRect
var pokemon_stats_open := false
var pokemon_stats_page := 0
var pokemon_stats_pokemon: Dictionary = {}
var pokemon_stats_return_context := ""
var battle_party_view: Control
var battle_party_cursor: Label
var battle_party_sprite: TextureRect
var battle_party_name: Label
var battle_party_level: Label
var battle_party_gender: TextureRect
var battle_party_hp_value: Label
var battle_party_hp_fill: ColorRect
var battle_party_prompt: Label
var battle_party_action_panel: Panel
var battle_party_action_cursor: TextureRect
var battle_party_action_list: Label
var battle_party_action_open := false
var battle_party_action_index := 0
var battle_party_action_entries: Array[String] = []
var battle_party_rows: Array[Dictionary] = []
var battle_clean_command_cursor: TextureRect
var evolution_cancel_requested := false
var evolution_greyscale_material: ShaderMaterial
var player_color_index := 0
var player_model_index := 0
var custom_player_name := ""
var player_appearance_texture_cache: Dictionary = {}
var current_species := ""
var current_level := 1
var caught_species = []
var pokedex_progress = preload("res://scripts/pokedex_progress.gd").new()
var pokedex_menu: Control
var android_back_bridge: Object
var android_back_bridge_checked := false
var caught_pokemon = []
var inventory: Dictionary = CraftingData.ensure_inventory(STARTING_INVENTORY)
var pokemon_storage: Dictionary = {}
## Single-player only: the box under this name is what every purple SHARED
## chest opens. It is kept in a file of its own beside the saves, so the same
## Pokemon are in it whichever single-player save is loaded. STORAGE BOXES are
## unchanged and belong to their own save.
const SHARED_STORAGE_KEY := "SHARED"
## The number the shared storage was last written under.
var shared_storage_serial := 0
var storage_menu: Control
var storage_rows: Array[Dictionary] = []
var storage_actions: Panel
var storage_action_labels: Array[Label] = []
var storage_footer_arrow: TextureRect
var storage_choice_panel: Panel
var storage_choice_arrow: TextureRect
var storage_choice_label: Label
var storage_no_label: Label
var storage_dialog: Panel
var storage_dialog_text: Label
var storage_nickname: LineEdit
var storage_mode := "LIST"
var storage_action_index := 0
var storage_yes := true
var storage_pending := ""
var storage_switch_from := -1
var storage_cursor: TextureRect
var storage_prompt: Label
const POKEMON_STORAGE_CAPACITY := 0 # 0 retains the source unlimited chest.
var overflow_recovery_notice := ""
var storage_pooled := false
var storage_menu_open := false
var storage_box_key := ""
var preferred_storage_box := ""
var storage_column := 0
var storage_index := 0
var storage_box_window_start := 0
var trainer_tip_open := false
var trainer_tip_pages: Array[String] = []
var trainer_tip_page_index := 0
var trainer_tip_continue: Label
var item_menu_names: Array[String] = []
var item_menu_index := 0
var item_menu_active := false
var item_pocket_context := ""
var bag_action_ui: Control
var safari_ui: Control
var map_build_serial := 0
var map_art_cache_key := ""
var map_art_cache: Texture2D
var map_building := false
var planting_bag_target: Variant = null
var field_item_busy := false
var sleeping_bag_heal_accumulator := 0.0
var craft_menu_open := false
var craft_station := ""
var craft_index := 0
var build_menu_open := false
var build_menu_index := 0
var resource_popup_timer := 0.0
var resource_popup_name := ""
var resource_popup_amount := 0
const SOURCE_MAP_TILE_PIXELS := 4
const DEFAULT_MAP_ZOOM := 3.0 / SOURCE_MAP_TILE_PIXELS
const MAP_MARKER_DISPLAY_SIZE := Vector2(13.0, 9.0)
const MAP_SLEEPING_BAG_DISPLAY_SIZE := Vector2(12.0, 8.0)
const MAP_SLEEPING_BAG_TEXTURE := preload("res://assets/source_ui/sleeping_bag1.png")
const M3924_MINIMAP_BORDER := preload("res://assets/source_ui/minimap_dialogue_circle.png")
const M3924_MINIMAP_SIZE := Vector2(64.0, 64.0)
const M3924_MINIMAP_MAP_SIZE := Vector2i(64, 64)
const M3924_MINIMAP_MAP_OFFSET := Vector2.ZERO
const M3924_MINIMAP_MAP_RADIUS := 26.4
const M3924_MINIMAP_WINDOW_CELLS := Vector2(24.0, 24.0)
const M3924_MINIMAP_REFRESH_SECONDS := 0.0
const MAP_VIEWPORT_CENTER := Vector2(160.0, 78.0)
const MAP_VIEWPORT_SIZE := Vector2(320.0, 156.0)
var map_zoom := DEFAULT_MAP_ZOOM
var map_pan := Vector2.ZERO
var map_art_cache_context := ""
var map_cache_warming := false
var map_cache_check_time := 0.0
var map_view_node: TextureRect
var map_marker_node: TextureRect
var map_sleeping_bag_node: TextureRect
var m3924_dig_panel: Panel
var m3924_dig_right_panel: Panel
var m3924_dig_left_label: Label
var m3924_dig_right_label: Label
var dig_reward_panel: Panel
var dig_reward_label: Label
var dig_reward_seconds := 0.0
var minimap_frame: TextureRect
var minimap_angle := 0.0
var minimap_north: Control
var minimap_frame_type := -1
var m3924_minimap_root: Control
var m3924_minimap_map: TextureRect
var m3924_minimap_player: TextureRect
var m3924_minimap_respawn: TextureRect
var m3924_minimap_last_player_cell := Vector2i(-2147483648, -2147483648)
var m3924_minimap_last_player_position := Vector2(-2147483648.0, -2147483648.0)
var m3924_minimap_last_bounds := Rect2i()
var m3924_minimap_last_respawn := Vector2i(-2147483648, -2147483648)
var m3924_minimap_refresh_accumulator := M3924_MINIMAP_REFRESH_SECONDS
var m3924_minimap_draw_size := Vector2i.ZERO
var m3924_minimap_draw_offset := Vector2i.ZERO
var m3924_minimap_texture_images := {}
var m3924_minimap_tile_previews := {}
var m3924_minimap_source_cache := {}
var m3924_minimap_cache_world_id := 0
var m3924_minimap_cache_discovered := -1
var m3924_minimap_cache_until := 0
var m257_minimap_raster_key: Array = []
var m257_minimap_raster_until := 0
var m257_minimap_recipes: Dictionary = {}
var teleport_map_mode := false
var teleport_destinations: Array = []
var teleport_destination_index := 0
var teleport_name_label: Label
var ball_mechanics: Node2D
var field_move_wheel: FieldMoveRadial
var field_move_wheel_open := false
var field_move_wheel_index := -1
var build_wheel_mode := false
var build_wheel_page := 0
var field_wheel_wait_for_release := false
var field_quick_tap_at := -1
var field_quick_tap_move := -1
const BUILD_WHEEL_PAGE_SIZE := 12
var last_android_back_msec := -10000
var game_menu_open := false
var game_menu_detail_open := false
var game_menu_index := 0
var guide_menu_open := false
var guide_topic_open := false
var guide_menu_index := 0
var pokemon_menu_open := false
var pokemon_menu_index := 0
var pokemon_move_index := 0
var egg_step_timer := 0
var friendship_step_timer := 0
var next_party_ecology_id := 1
var save_confirm_open := false
var save_confirm_index := 0
var quit_prompt_open := false
var quit_prompt_stage := 0 # 0 = quit?, 1 = save before quit?
var quit_prompt_index := 0 # 0 = YES, 1 = NO
var egg_pickup_open := false
var egg_pickup_stage := 0 # 0 = discovery text, 1 = YES/NO
var egg_pickup_index := 0 # 0 = YES, 1 = NO
var egg_pickup_cell := Vector2i(-2147483648, -2147483648)
var egg_dialogue_panel: Panel
var egg_dialogue_label: Label
var egg_dialogue_arrow: Label
var egg_choice_panel: Panel
var egg_choice_cursor: Label
var wild_pokemon_prompt_open := false
var wild_pokemon_prompt_stage := 0
var wild_pokemon_prompt_index := 0
var wild_pokemon_prompt_id := -1
var wild_pokemon_prompt_species := ""
var wild_pokemon_prompt_kind := ""
var deployed_prompt_cell := Vector2i.ZERO
# A wild-Pokemon prompt is opened synchronously by the same A/confirm event
# that interacted with the overworld Pokemon. Do not allow that opening press
# to also dismiss or advance the new prompt: arm confirmation only after the
# player releases A/start, so the next confirmation is a genuinely new press.
var wild_pokemon_prompt_confirm_armed := false
var wild_dialogue_panel: Panel
var wild_dialogue_label: Label
var wild_dialogue_arrow: Label
var wild_choice_panel: Panel
var wild_choice_cursor: Label
const GAME_MENU_OPTIONS := ["POKEDEX", "POKEMON", "ITEM", "STORAGE", "MAP", "GUIDE", "OPTIONS", "SAVE", "EXIT"]
const GameOptions = preload("res://scripts/game_options.gd")
var options_menu: Control
var game_files_menu: Control
var message_reveal_elapsed := 0.0
var message_reveal_text := ""
const GUIDE_TOPICS := [
    {
        "name": "FIELD MOVES",
        "body": "Stand still while holding X to stop using a Field Move."
    },
    {
        "name": "CRAFTING",
        "body": "You can craft items at a campfire. Craft POKE BALLS using Apricorns."
    },
    {
        "name": "FAINTING",
        "body": "If you white out during battle, you will return to the last place you used a sleeping bag."
    },
    {
        "name": "GHOSTS",
        "body": "Ghosts may appear in the woods at night. A campfire will ward them off."
    },
    {
        "name": "BUILDING 1",
        "body": "Grass types know CUT. Use CUT on trees and tall grass to get building materials."
    },
    {
        "name": "BUILDING 2",
        "body": "Fighting-types know BUILD. Use CUT on buildings to remove them."
    },
    {
        "name": "BREEDING 3",
        "body": "POKEMON will lay EGGS when located near a compatible mate."
    },
    {
        "name": "HABITATS 1",
        "body": "Build fences to prevent your POKEMON from wandering off when you let them out of their POKE BALL."
    },
    {
        "name": "HABITATS 2",
        "body": "Your POKEMON will be happier if fenced in and located near a shelter."
    },
    {
        "name": "HABITATS 3",
        "body": "POKEMON are happier in their natural habitat. If happy enough, they may give you items!"
    },
    {
        "name": "WILDS EGGS",
        "body": "Be wary of taking EGGS near wild POKEMON. Angry parents may attack!"
    },
    {
        "name": "BACK DOORS",
        "body": "Build a door between two house tiles to make a back or side door to your house."
    },
    {
        "name": "HEALING 1",
        "body": "Sleeping indoors restores HP twice as fast as sleeping outdoors."
    },
    {
        "name": "HEALING 2",
        "body": "Sleeping in a bed will over time cure your POKEMON's status conditions."
    },
    {
        "name": "HEALING 3",
        "body": "Using your sleeping bag will slowly restore your party's HP."
    },
    {
        "name": "ESCAPE ROPE",
        "body": "Use the ESCAPE ROPE to return to the nearest location on the shore."
    },
    {
        "name": "PLANTS",
        "body": "Plant Miracle Seeds and Apricorns to grow grass and trees."
    },
    {
        "name": "GATES",
        "body": "Build a gate by building a door between two fences."
    },
    {
        "name": "EGGS",
        "body": "Eggs must be carried to hatch. RIDE counts while FLY does not."
    },
    {
        "name": "ROCK SMASH",
        "body": "Rock types know SMASH. Use it on boulders to collect rocks. Rocks respawn daily."
    },
    {
        "name": "SOFT BED 1",
        "body": "Collect Soft Feather and Silky Thread to make a soft bed for your home."
    },
    {
        "name": "SOFT BED 2",
        "body": "Bug types drop Silky Thread. Flying types drop Soft Feather."
    }
]
var message_timer := 0.0
var coop_game: Node
var coop_menu: Control
var online_label: Label
var menu_row := 0
var menu_col := 0
var selected_mode := "NEW"
var selected_world_size := 1 # S=0, M=1, L=2, XL=3, XXL=4
var menu_nav_cooldown := 0.0
const MENU_NAV_DELAY := 0.18
const MENU_STICK_ACTIVATION := 0.72
const MENU_STICK_RELEASE := 0.38
const MENU_STICK_REPEAT_MSEC := 320
var last_menu_stick_token := 0
var last_menu_stick_msec := -10000
var menu_stick_state_by_device: Dictionary = {}

const MENU_ROW_LOCAL := 0
const MENU_ROW_MODE := 1
const MENU_ROW_SIZE := 2
const MENU_ROW_WORLD_NAME := 3
const MENU_ROW_PLAYER_NAME := 4
const MENU_ROW_COLOR := 5
const MENU_ROW_GO := 6

const WORLD_SIZE_NAMES := ["S", "M", "L", "XL", "XXL"]
const BUILD_COST_READY_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const BUILD_COST_MISSING_COLOR := Color(0.52, 0.52, 0.52, 1.0)

var text_entry_target := "" # "" or "world"
var text_entry_buffer := ""
var new_world_sequence := 0

var startup_complete := false
var shared_save_folder: Node

var dark_mode_ui: Node

func _ready() -> void:
    # Keep initialization and Android folder synchronization offscreen.
    $UI.hide()
    world.hide()
    generation_panel.hide()
    var storage_error := DataPaths.initialize()
    if storage_error != OK: push_error("Could not prepare game files: %s" % error_string(storage_error))
    shared_save_folder = preload("res://scripts/shared_save_folder.gd").new()
    add_child(shared_save_folder)
    set_process(false)
    set_process_input(false)
    set_process_unhandled_input(false)
    await shared_save_folder.prepare(self)
    SAVE_DIR = DataPaths.path("saves")
    SAVE_INDEX_PATH = DataPaths.path("saves/index.cfg")
    GameOptions.load_settings()
    GameOptions.reset_launch_options()
    GameOptions.apply_audio()
    shared_save_folder.start_exports.call_deferred(self)
    _setup_options.call_deferred()
    _setup_generation_clouds()
    _build_m66_source_ui()
    _build_m3924_dig_minimap_ui()
    world.visible = false
    setup_panel.visible = false
    generation_panel.visible = false
    battle_panel.visible = false
    battle_submenu.visible = false
    battle_move_animation.texture = null
    progression_overlay.visible = false
    setup_load_panel.visible = false
    pokemon_stats_overlay.visible = false
    battle_party_view.visible = false
    progression_animation.texture = null
    _create_evolution_greyscale_material()
    battle_move_type_box.visible = false
    battle_move_box.visible = false
    battle_message_arrow.visible = false
    _update_battle_command_cursor()
    message_panel.visible = false
    touch_config.visible = false
    game_menu.visible = false
    game_menu_map_screen.visible = false
    item_pocket_menu.z_index = 100
    item_pocket_menu.visible = false
    save_confirm.visible = false
    quit_prompt.visible = false
    crafting_panel.visible = false
    build_panel.visible = false
    resource_popup.visible = false
    battle_transition.visible = false
    field_move_wheel = FieldMoveRadial.new()
    field_move_wheel.name = "FieldMoveWheel"
    field_move_wheel.z_index = 250
    $UI.add_child(field_move_wheel)
    touch_controls.set_game_active(true)
    battle_rng.randomize()
    _load_battle_animation_manifest()

    world_edit.text = "PokeWilds"
    _load_setup()
    _update_classic_menu_labels()

    # WORLD NAME uses the source-style 24-character entry buffer. Keep the
    # LineEdit itself out of keyboard/controller focus so its native caret
    # handling cannot consume D-pad navigation or resize the field while typing.
    world_edit.focus_mode = Control.FOCUS_NONE
    world_edit.expand_to_text_length = false
    world_edit.mouse_filter = Control.MOUSE_FILTER_STOP

    player_preview.hframes = 8
    player_preview.frame = 0
    _apply_player_appearance()

    start_button.pressed.connect(_start_game)
    $UI/SetupPanel/ColorUp.pressed.connect(_next_color)
    $UI/SetupPanel/ColorDown.pressed.connect(_previous_color)
    $UI/SetupPanel/ModelUp.pressed.connect(_next_model)
    $UI/SetupPanel/ModelDown.pressed.connect(_previous_model)

    world_edit.gui_input.connect(_display_field_gui_input.bind("world"))
    world_edit.max_length = 24
    player_model_name.mouse_filter = Control.MOUSE_FILTER_STOP
    player_model_name.gui_input.connect(_display_field_gui_input.bind("player"))
    player_model_name.size.x = 210
    _fit_player_name()

    world.generation_progress.connect(_on_generation_progress)
    world.encounter_requested.connect(_on_encounter_requested)
    if world.has_signal("battle_requested"):
        world.connect("battle_requested", Callable(self, "_on_battle_requested"))
    world.world_message.connect(_show_message)
    world.unown_message.connect(_show_unown_message)
    if world.has_signal("trainer_tip_message"):
        world.connect("trainer_tip_message", Callable(self,
            "_show_trainer_tip_message"))
    if world.has_signal("item_collected"):
        world.connect("item_collected", Callable(self, "_on_item_collected"))
    world.crafting_station_requested.connect(_open_crafting_menu)
    world.material_collected.connect(_on_material_collected)
    world.connect("dig_reward_collected", Callable(self, "_on_dig_reward_collected"))
    if world.has_signal("material_bundle_collected"):
        world.connect("material_bundle_collected", Callable(self, "_on_material_bundle_collected"))
    if world.has_signal("paint_requested"):
        world.connect("paint_requested", Callable(self, "_on_paint_requested"))
    if world.has_signal("teleport_map_requested"):
        world.connect("teleport_map_requested", Callable(self, "_open_teleport_map"))
    world.build_requested.connect(_on_build_requested)
    if world.has_signal("build_selection_changed"):
        world.connect(
            "build_selection_changed",
            Callable(self, "_on_world_build_selection_changed")
        )
    if world.has_signal("dig_requested"):
        world.connect("dig_requested", Callable(self, "_on_dig_requested"))
    world.build_refund_requested.connect(_on_build_refund_requested)
    if world.has_signal("structure_removal_requested"):
        world.connect("structure_removal_requested", Callable(self, "_on_structure_removal_requested"))
    world.pokemon_recalled.connect(_on_pokemon_recalled)
    world.deployed_recall_requested.connect(_on_deployed_recall_requested)
    world.structure_action.connect(_on_structure_action)
    _create_sign_editor()
    if world.has_signal("egg_collected"):
        world.connect("egg_collected", Callable(self, "_on_egg_collected"))
    if world.has_signal("egg_pickup_prompt_requested"):
        world.connect(
            "egg_pickup_prompt_requested",
            Callable(self, "_on_egg_pickup_prompt_requested")
        )
    if world.has_signal("wild_pokemon_prompt_requested"):
        world.connect(
            "wild_pokemon_prompt_requested",
            Callable(self, "_on_wild_pokemon_prompt_requested")
        )
    if world.has_signal("player_stepped"):
        world.connect("player_stepped", Callable(self, "_on_player_stepped"))
    if world.has_signal("pokemon_ecology_changed"):
        world.connect(
            "pokemon_ecology_changed",
            Callable(self, "_on_pokemon_ecology_changed")
        )

    fight_button.pressed.connect(_open_battle_move_menu)
    item_button.pressed.connect(_open_battle_item_menu)
    party_button.pressed.connect(_open_battle_party_menu.bind("PARTY"))
    catch_button.pressed.connect(_battle_catch)
    run_button.pressed.connect(_battle_run)

    show_touch.button_pressed = touch_controls.touch_enabled
    auto_hide.button_pressed = touch_controls.auto_hide_controller
    touch_opacity_slider.value = touch_controls.control_opacity * 100.0
    touch_size_slider.value = touch_controls.control_scale * 100.0
    show_touch.toggled.connect(_show_touch_changed)
    auto_hide.toggled.connect(_auto_hide_changed)
    touch_opacity_slider.value_changed.connect(_touch_opacity_changed)
    touch_size_slider.value_changed.connect(_touch_size_changed)
    touch_theme_button.pressed.connect(_cycle_touch_theme)
    touch_controls.control_theme_changed.connect(_on_touch_theme_changed)
    touch_controls.touch_config_requested.connect(
        _open_touch_config
    )
    $UI/TouchConfig/VBox/MoveControls.pressed.connect(_move_controls)
    $UI/TouchConfig/VBox/ResetLayout.pressed.connect(_reset_layout)
    $UI/TouchConfig/VBox/Close.pressed.connect(_close_touch_config)
    var files_button := Button.new()
    files_button.name="GameFiles";files_button.text="GAME FILES"
    $UI/TouchConfig/VBox.add_child(files_button)
    $UI/TouchConfig/VBox.move_child(files_button,$UI/TouchConfig/VBox/Close.get_index())
    files_button.pressed.connect(_open_game_files_menu)
    var mods_button := Button.new()
    mods_button.name="Modding";mods_button.text="MODDING"
    $UI/TouchConfig/VBox.add_child(mods_button)
    $UI/TouchConfig/VBox.move_child(mods_button,files_button.get_index()+1)
    mods_button.pressed.connect(_open_modding_menu)
    _refresh_touch_config_labels()
    _apply_touch_config_theme()

    coop_game = preload("res://scripts/coop_game.gd").new()
    add_child(coop_game)
    coop_game.configure(self)
    coop_menu = preload("res://scripts/coop_menu.gd").new()
    $UI.add_child(coop_menu)
    coop_menu.configure(self)
    coop_menu.chosen.connect(coop_game.choose)
    var mode_label: Label = $UI/SetupPanel/ModeLabel
    online_label = _source_ui_label(setup_panel,"OnlineLabel",
        Vector2(mode_label.position.x + JOHTO_FONT.get_string_size("NEW        ",HORIZONTAL_ALIGNMENT_LEFT,-1,12).x,6),
        Vector2(80,18),12,"BACK")
    # The top row is one control: BACK to the SINGLE PLAYER / MULTIPLAYER choice.
    # The current mode is already shown in the status corner.
    online_label.hide()
    var back_label := $UI/SetupPanel/LocalLabel as Label
    back_label.text="BACK"
    back_label.mouse_filter=Control.MOUSE_FILTER_STOP
    back_label.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not started and not generating:
            menu_row=MENU_ROW_LOCAL;menu_col=0;_update_menu_cursor();coop_game.cancel_join();coop_menu.open())
    _setup_menu_navigation()
    _create_egg_pickup_ui()
    _create_wild_pokemon_prompt_ui()
    _update_classic_menu_labels()
    _update_menu_cursor()
    $UI.set_script(preload("res://scripts/proportional_ui_layout.gd"))
    $UI._ready()
    setup_panel.show()
    $UI.show()
    $StartupSplash.hide()
    # First choice after the splash: SINGLE PLAYER or MULTIPLAYER.
    coop_menu.open()
    dark_mode_ui = preload("res://scripts/dark_mode.gd").new()
    add_child(dark_mode_ui)
    dark_mode_ui.configure($UI)
    dark_mode_ui.set_enabled(GameOptions.enabled("dark_mode"))
    startup_complete = true
    set_process(true)
    set_process_input(true)
    set_process_unhandled_input(true)

func _create_egg_pickup_ui() -> void:
    # Dedicated source-style egg prompt. It reuses the exact border and fonts
    # used by the rest of this port instead of introducing a second UI theme.
    egg_dialogue_panel = Panel.new()
    egg_dialogue_panel.name = "EggDialogue"
    # Match the compact source dialogue footprint instead of covering half of
    # the 320x180 playfield. Keep the approved border/font and anchor it at the
    # bottom edge exactly like the other source-style message boxes.
    # Keep the compact bar from M74.3.9.1, but give the two-line egg reveal
    # six more pixels of vertical breathing room. Preserve the same 2 px side
    # inset and 2 px bottom inset on the 320x180 source viewport.
    egg_dialogue_panel.position = Vector2(2, 126)
    egg_dialogue_panel.size = Vector2(316, 52)
    egg_dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    egg_dialogue_panel.add_theme_stylebox_override("panel", _classic_dialogue_style())
    egg_dialogue_panel.visible = false
    $UI.add_child(egg_dialogue_panel)

    egg_dialogue_label = _source_ui_label(
        egg_dialogue_panel, "Message", Vector2(14, 6), Vector2(278, 40),
        10, ""
    )
    egg_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    egg_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    egg_dialogue_arrow = _source_ui_label(
        egg_dialogue_panel, "Arrow", Vector2(282, 30), Vector2(20, 16),
        10, "▼", true
    )
    egg_dialogue_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    egg_choice_panel = Panel.new()
    egg_choice_panel.name = "EggChoice"
    # Keep the YES/NO box exactly attached to the message bar's top-right
    # corner, but trim the oversized empty padding from the previous pass.
    # Right edge: 318 px. Bottom edge: 126 px, exactly matching the dialogue.
    egg_choice_panel.position = Vector2(234, 56)
    egg_choice_panel.size = Vector2(84, 70)
    egg_choice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    egg_choice_panel.add_theme_stylebox_override("panel", _classic_dialogue_style())
    egg_choice_panel.visible = false
    $UI.add_child(egg_choice_panel)

    egg_choice_cursor = _source_ui_label(
        egg_choice_panel, "Cursor", Vector2(11, 9), Vector2(14, 20),
        10, "▶", true
    )
    egg_choice_cursor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var egg_yes := _source_ui_label(
        egg_choice_panel, "Yes", Vector2(28, 10), Vector2(46, 22), 10, "YES"
    )
    var egg_no := _source_ui_label(
        egg_choice_panel, "No", Vector2(28, 38), Vector2(46, 22), 10, "NO"
    )
    egg_yes.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    egg_no.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _create_wild_pokemon_prompt_ui() -> void:
    # Deliberately clone the egg prompt geometry/theme so wild interactions
    # retain the user's approved text, border and aligned YES/NO ticks.
    wild_dialogue_panel = Panel.new()
    wild_dialogue_panel.name = "WildPokemonDialogue"
    wild_dialogue_panel.position = Vector2(2, 126)
    wild_dialogue_panel.size = Vector2(316, 52)
    wild_dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    wild_dialogue_panel.add_theme_stylebox_override("panel", _classic_dialogue_style())
    wild_dialogue_panel.visible = false
    $UI.add_child(wild_dialogue_panel)

    wild_dialogue_label = _source_ui_label(
        wild_dialogue_panel, "Message", Vector2(14, 6), Vector2(278, 40), 10, ""
    )
    wild_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    wild_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    wild_dialogue_arrow = _source_ui_label(
        wild_dialogue_panel, "Arrow", Vector2(282, 30), Vector2(20, 16),
        10, "▼", true
    )
    wild_dialogue_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    wild_choice_panel = Panel.new()
    wild_choice_panel.name = "WildPokemonChoice"
    wild_choice_panel.position = Vector2(234, 56)
    wild_choice_panel.size = Vector2(84, 70)
    wild_choice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    wild_choice_panel.add_theme_stylebox_override("panel", _classic_dialogue_style())
    wild_choice_panel.visible = false
    $UI.add_child(wild_choice_panel)

    wild_choice_cursor = _source_ui_label(
        wild_choice_panel, "Cursor", Vector2(11, 9), Vector2(14, 20),
        10, "▶", true
    )
    wild_choice_cursor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var wild_yes := _source_ui_label(
        wild_choice_panel, "Yes", Vector2(28, 10), Vector2(46, 22), 10, "YES"
    )
    var wild_no := _source_ui_label(
        wild_choice_panel, "No", Vector2(28, 38), Vector2(46, 22), 10, "NO"
    )
    wild_yes.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    wild_no.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _build_m3924_dig_minimap_ui() -> void:
    # DIG uses the same two-box source UI geometry as BUILD/CRAFTING.
    m3924_dig_panel = Panel.new()
    m3924_dig_panel.name = "DigPanel"
    m3924_dig_panel.position = Vector2(2.0, 2.0)
    m3924_dig_panel.size = Vector2(140.0, 48.0)
    m3924_dig_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    m3924_dig_panel.add_theme_stylebox_override("panel", _classic_dialogue_style())
    m3924_dig_panel.visible = false
    $UI.add_child(m3924_dig_panel)

    m3924_dig_right_panel = Panel.new()
    m3924_dig_right_panel.name = "DigGetPanel"
    m3924_dig_right_panel.position = Vector2(176.0, 0.0)
    m3924_dig_right_panel.size = m3924_dig_panel.size
    m3924_dig_right_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    m3924_dig_right_panel.add_theme_stylebox_override("panel", _classic_dialogue_style())
    m3924_dig_panel.add_child(m3924_dig_right_panel)

    m3924_dig_left_label = _source_ui_label(
        m3924_dig_panel, "DigSoil", Vector2(14.0, 8.0), Vector2(114.0, 34.0), 8, "DIG")
    m3924_dig_left_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    m3924_dig_right_label = _source_ui_label(
        m3924_dig_right_panel, "DigResult", Vector2(14.0, 8.0), Vector2(114.0, 34.0), 8, "GET")
    m3924_dig_right_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dig_reward_panel = Panel.new()
    dig_reward_panel.name = "DigRewardPanel"
    dig_reward_panel.position = m3924_dig_right_panel.position
    dig_reward_panel.size = m3924_dig_right_panel.size
    dig_reward_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dig_reward_panel.add_theme_stylebox_override("panel", _classic_dialogue_style())
    dig_reward_panel.hide()
    m3924_dig_panel.add_child(dig_reward_panel)
    dig_reward_label = _source_ui_label(dig_reward_panel, "Reward",
        m3924_dig_right_label.position, m3924_dig_right_label.size, 8)
    dig_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    # Independent static compass/minimap. It never reuses/reparents the full map.
    m3924_minimap_root = Control.new()
    m3924_minimap_root.name = "WorldMiniMap"
    m3924_minimap_root.position = Vector2(2.0, 2.0)
    m3924_minimap_root.size = M3924_MINIMAP_SIZE
    m3924_minimap_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    m3924_minimap_root.z_index = 80
    m3924_minimap_root.visible = false
    $UI.add_child(m3924_minimap_root)

    m3924_minimap_map = _source_texture_rect(
        m3924_minimap_root, "Map", M3924_MINIMAP_MAP_OFFSET,
        Vector2(M3924_MINIMAP_MAP_SIZE), null)
    m3924_minimap_map.stretch_mode = TextureRect.STRETCH_SCALE
    m3924_minimap_map.z_index = 1

    var backing := ColorRect.new()
    backing.name = "FrameBacking"
    backing.color = Color(0.025, 0.035, 0.03)
    backing.size = M3924_MINIMAP_SIZE
    backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
    m3924_minimap_root.add_child(backing)
    m3924_minimap_root.move_child(backing, 0)
    minimap_frame = TextureRect.new()
    minimap_frame.name = "SelectedFrame"
    minimap_frame.size = M3924_MINIMAP_SIZE
    minimap_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    minimap_frame.stretch_mode = TextureRect.STRETCH_SCALE
    minimap_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var minimap_ring_material := ShaderMaterial.new()
    minimap_ring_material.shader = preload("res://scripts/radial_frame.gdshader")
    minimap_ring_material.set_shader_parameter("base_radius", 64.0)
    minimap_ring_material.set_shader_parameter("border_outset", 0.0)
    minimap_frame.material = minimap_ring_material
    minimap_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    minimap_frame.z_index = 5
    m3924_minimap_root.add_child(minimap_frame)
    minimap_north = preload("res://scripts/minimap_north.gd").new()
    minimap_north.name="North"
    m3924_minimap_root.add_child(minimap_north)
    var border_layers := _m3924_minimap_border_layers()
    var outer_border: TextureRect = _source_texture_rect(
        m3924_minimap_root, "OuterBlackBorder", Vector2.ZERO,
        M3924_MINIMAP_SIZE, border_layers["outer"])
    outer_border.stretch_mode = TextureRect.STRETCH_SCALE
    outer_border.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    outer_border.z_index = 4
    var border: TextureRect = _source_texture_rect(
        m3924_minimap_root, "DialogueCircleBorder", Vector2.ZERO,
        M3924_MINIMAP_SIZE, border_layers["inner"])
    border.stretch_mode = TextureRect.STRETCH_SCALE
    border.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    border.z_index = 5
    m3924_minimap_player = _source_texture_rect(
        m3924_minimap_root, "Player", Vector2.ZERO, Vector2(7.0, 5.0), null)
    var appearance_texture: Texture2D = _player_appearance_texture(false)
    if appearance_texture != null and (not m3924_minimap_player.texture is AtlasTexture or (m3924_minimap_player.texture as AtlasTexture).atlas != appearance_texture):
        var marker_frame: AtlasTexture = AtlasTexture.new()
        marker_frame.atlas = appearance_texture
        marker_frame.region = Rect2(0.0, 0.0, 16.0, 11.0)
        m3924_minimap_player.texture = marker_frame
    m3924_minimap_player.z_index = 4

    m3924_minimap_respawn = _source_texture_rect(
        m3924_minimap_root, "Respawn", Vector2.ZERO, Vector2(6.0, 4.0), MAP_SLEEPING_BAG_TEXTURE)
    m3924_minimap_respawn.z_index = 3
    m3924_minimap_respawn.visible = false

func _m3924_minimap_border_layers() -> Dictionary:
    var inner: Image = M3924_MINIMAP_BORDER.get_image().duplicate()
    _m3924_fit_minimap_ornaments(inner)
    var outer := Image.create(inner.get_width(), inner.get_height(),
        false, Image.FORMAT_RGBA8)
    outer.fill(Color.TRANSPARENT)
    for y in range(inner.get_height()):
        var first_border := -1
        var last_border := -1
        for x in range(inner.get_width()):
            var pixel := inner.get_pixel(x, y)
            if pixel.a > 0.0 and maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.1:
                if first_border < 0:
                    first_border = x
                last_border = x
        if first_border < 0:
            first_border = inner.get_width()
        for x in range(first_border):
            if inner.get_pixel(x, y).a > 0.0:
                outer.set_pixel(x, y, Color.BLACK)
            inner.set_pixel(x, y, Color.TRANSPARENT)
        for x in range(last_border + 1, inner.get_width()):
            if inner.get_pixel(x, y).a > 0.0:
                outer.set_pixel(x, y, Color.BLACK)
            inner.set_pixel(x, y, Color.TRANSPARENT)
    return {
        "outer": ImageTexture.create_from_image(outer),
        "inner": ImageTexture.create_from_image(inner)
    }

func _m3924_fit_minimap_ornaments(border: Image) -> void:
    # Keep each ornament's center and colors, but reduce its black backing by
    # one source pixel per side at the 64-pixel minimap display size.
    var patches := [
        [Rect2i(240, 8, 40, 48), Rect2i(244, 12, 32, 40), true],
        [Rect2i(240, 456, 40, 48), Rect2i(244, 460, 32, 40), true],
        [Rect2i(8, 240, 48, 40), Rect2i(12, 244, 40, 32), false],
        [Rect2i(456, 240, 48, 40), Rect2i(460, 244, 40, 32), false]
    ]
    for patch in patches:
        var original: Rect2i = patch[0]
        var fitted: Rect2i = patch[1]
        var horizontal: bool = patch[2]
        var ornament := border.get_region(original)
        for y in range(original.position.y, original.end.y):
            for x in range(original.position.x, original.end.x):
                var reference: Vector2i
                if horizontal:
                    reference = Vector2i(original.position.x - 1 if x < 260
                        else original.end.x, y)
                else:
                    reference = Vector2i(x, original.position.y - 1 if y < 260
                        else original.end.y)
                border.set_pixel(x, y, border.get_pixelv(reference))
        ornament.resize(fitted.size.x, fitted.size.y, Image.INTERPOLATE_NEAREST)
        border.blit_rect(ornament, Rect2i(Vector2i.ZERO, fitted.size), fitted.position)

func _m3924_minimap_top_box_visible(ignore_dig: bool = false) -> bool:
    if not started or generating or battle_active or progression_active:
        return true
    if setup_panel.visible or touch_config.visible or game_menu_open or quit_prompt_open:
        return true
    if craft_menu_open or build_menu_open or resource_popup.visible:
        return true
    if not ignore_dig and m3924_dig_panel != null and m3924_dig_panel.visible:
        return true
    # Dynamically-created storage/sign/etc. top panels should also hide it. Keep
    # the explicitly approved bottom egg/wild dialogue and normal message boxes.
    for raw_child in $UI.get_children():
        if not (raw_child is Control):
            continue
        var child: Control = raw_child as Control
        if not child.visible or child == m3924_minimap_root or (ignore_dig and child == m3924_dig_panel):
            continue
        if child == message_panel or child == egg_dialogue_panel or child == egg_choice_panel or child == wild_dialogue_panel or child == wild_choice_panel:
            continue
        if child.name in ["TouchControls", "WorldMiniMap"]:
            continue
        if child is Panel and child.position.y < 86.0 and child.size.y > 12.0:
            return true
    return false

func _update_m3924_dig_hud_and_minimap(delta: float) -> void:
    if m3924_dig_panel == null or m3924_minimap_root == null:
        return
    var dig_selected := String(world.get("active_field_move")) == "DIG"
    var dig_active: bool = started and world.visible and dig_selected and not _m3924_minimap_top_box_visible(true)
    dig_active = dig_active and not storage_menu_open and not storage_menu.visible and not trainer_tip_open and not field_move_wheel_open and not sign_dialog.visible
    if not dig_selected:
        dig_reward_seconds = 0.0
    elif dig_active:
        dig_reward_seconds = maxf(0.0, dig_reward_seconds - delta)
    dig_reward_panel.visible = dig_reward_seconds > 0.0
    m3924_dig_right_panel.visible = not dig_reward_panel.visible
    m3924_dig_panel.visible = dig_active
    if dig_active and world.has_method("get_dig_hud_state"):
        var state: Dictionary = world.call("get_dig_hud_state")
        m3924_dig_left_label.text = String(state.get("left", "DIG"))
        m3924_dig_right_label.text = String(state.get("right", ""))
        _fit_compact_dig_label(m3924_dig_right_label)
        m3924_dig_left_label.modulate = Color.WHITE if bool(state.get("diggable", false)) else Color(0.55, 0.55, 0.55, 1.0)
    var minimap_should_show: bool = GameOptions.enabled("minimap") and started and world.visible and not _m3924_minimap_top_box_visible()
    m3924_minimap_root.visible = minimap_should_show
    if not minimap_should_show:
        return
    var player_node: Node2D = world.get_node_or_null("Player") as Node2D
    if player_node == null:
        return
    var player_position: Vector2 = player_node.position
    var player_cell: Vector2i = Vector2i(
        int(floor(player_position.x / 16.0)), int(floor(player_position.y / 16.0)))
    var bounds: Rect2i = Rect2i(Vector2i.ZERO, Vector2i(int(world.get("map_w")), int(world.get("map_h"))))
    if world.has_method("get_map_bounds"):
        bounds = world.call("get_map_bounds")
    var respawn_cell: Vector2i = world.get("respawn_cell")
    var bounds_changed: bool = bounds != m3924_minimap_last_bounds
    var respawn_changed: bool = respawn_cell != m3924_minimap_last_respawn
    var player_position_changed: bool = player_position != m3924_minimap_last_player_position
    m3924_minimap_refresh_accumulator += delta
    if (
            bounds_changed
            or respawn_changed
            # While moving, 20 times a second is as smooth as the minimap's
            # few pixels can show; every frame cost about 4 ms.
            or (player_position_changed and m3924_minimap_refresh_accumulator >= 0.05)
            or m3924_minimap_map.texture == null
            or m3924_minimap_refresh_accumulator >= M3924_MINIMAP_REFRESH_SECONDS
        ):
        m3924_minimap_refresh_accumulator = 0.0
        m3924_minimap_last_bounds = bounds
        m3924_minimap_last_respawn = respawn_cell
        m3924_minimap_last_player_position = player_position
        _refresh_m3924_minimap(bounds, player_position)
    _apply_minimap_rotation(delta)
    m3924_minimap_last_player_cell = player_cell

func _refresh_minimap_frame() -> void:
    if not is_instance_valid(minimap_frame): return
    var frame := int(GameOptions.values.frame)
    var original := frame == 0
    for key in ["OuterBlackBorder", "DialogueCircleBorder"]:
        m3924_minimap_root.get_node(key).visible = original
    m3924_minimap_root.get_node("FrameBacking").hide()
    minimap_frame.visible = not original
    minimap_north.visible = not original
    if frame != minimap_frame_type:
        minimap_frame_type = frame
        minimap_frame.texture = ImageTexture.create_from_image(GameOptions.frame_texture().get_image())

func _apply_minimap_rotation(delta: float = 1.0) -> void:
    minimap_angle = 0.0
    var angle:=minimap_angle
    _refresh_minimap_frame()
    m3924_minimap_map.pivot_offset = m3924_minimap_map.size * 0.5
    m3924_minimap_map.rotation = angle
    for key in ["OuterBlackBorder", "DialogueCircleBorder"]:
        var border := m3924_minimap_root.get_node(key) as Control
        border.pivot_offset = border.size * 0.5
        border.rotation = angle
    minimap_north.position = (M3924_MINIMAP_SIZE * 0.5 + Vector2(0,-29).rotated(angle) - minimap_north.size * 0.5).round()
    if m3924_minimap_respawn.visible:
        var center := M3924_MINIMAP_MAP_OFFSET + Vector2(M3924_MINIMAP_MAP_SIZE) * 0.5
        var unrotated: Vector2 = m3924_minimap_respawn.get_meta("unrotated_position", m3924_minimap_respawn.position)
        m3924_minimap_respawn.position = center + (unrotated + m3924_minimap_respawn.size * 0.5 - center).rotated(angle) - m3924_minimap_respawn.size * 0.5
    if is_instance_valid(waypoint_ui):waypoint_ui.update_minimap(angle)

func _refresh_m3924_minimap(bounds: Rect2i, player_position: Vector2) -> void:
    if bounds.size.x <= 0 or bounds.size.y <= 0:
        return
    var appearance_texture: Texture2D = _player_appearance_texture(false)
    if appearance_texture != null:
        var marker_frame: AtlasTexture = AtlasTexture.new()
        marker_frame.atlas = appearance_texture
        marker_frame.region = Rect2(0.0, 0.0, 16.0, 11.0)
        m3924_minimap_player.texture = marker_frame
    var canvas_size: Vector2i = M3924_MINIMAP_MAP_SIZE
    var map_center: Vector2 = Vector2(float(canvas_size.x) * 0.5, float(canvas_size.y) * 0.5)
    var map_diameter: float = M3924_MINIMAP_MAP_RADIUS * 2.0
    var map_left: float = map_center.x - M3924_MINIMAP_MAP_RADIUS
    var map_top: float = map_center.y - M3924_MINIMAP_MAP_RADIUS
    var player_cell_position: Vector2 = player_position / 16.0
    var indoor := world.interior_map_image(bounds) != null
    # Fit the floor's diagonal in the circular view, preserving centered-player
    # panning and uniform scale. Outdoors retain the approved 24-cell window.
    var centered := indoor
    var window_cells := M3924_MINIMAP_WINDOW_CELLS
    if indoor:
        window_cells = Vector2.ONE * maxf(24.0, Vector2(bounds.size).length() + 2.0)
    var half_window: Vector2 = window_cells * 0.5
    var view_origin: Vector2 = player_cell_position - half_window
    var min_origin_x: float = float(bounds.position.x)
    var min_origin_y: float = float(bounds.position.y)
    var max_origin_x: float = float(bounds.position.x + bounds.size.x) - window_cells.x
    var max_origin_y: float = float(bounds.position.y + bounds.size.y) - window_cells.y
    if max_origin_x < min_origin_x:
        max_origin_x = min_origin_x
    if max_origin_y < min_origin_y:
        max_origin_y = min_origin_y
    view_origin.x = clampf(view_origin.x, min_origin_x, max_origin_x)
    view_origin.y = clampf(view_origin.y, min_origin_y, max_origin_y)
    # A shift of one map pixel must move every terrain sample by the same
    # pixel. Fractional origins resample cell edges independently each frame.
    var cells_per_pixel: Vector2 = window_cells / map_diameter
    view_origin.x = clampf(roundf(view_origin.x / cells_per_pixel.x) * cells_per_pixel.x,
        min_origin_x, max_origin_x)
    view_origin.y = clampf(roundf(view_origin.y / cells_per_pixel.y) * cells_per_pixel.y,
        min_origin_y, max_origin_y)
    if centered:
        view_origin = player_cell_position - half_window
        view_origin = (view_origin / cells_per_pixel).round() * cells_per_pixel
    var exact = world.get("exact_world")
    m3924_minimap_map.set_meta("view_origin",view_origin)
    m3924_minimap_map.set_meta("window_cells",window_cells)
    var raster_key: Array = [bounds, view_origin, window_cells, indoor, centered,
        0 if exact == null else exact.get_instance_id(),
        (world.get("discovered_cells") as Dictionary).size() if Time.get_ticks_msec() - m3924_minimap_cache_built >= 400 else m3924_minimap_cache_discovered]
    if raster_key == m257_minimap_raster_key and Time.get_ticks_msec() < m257_minimap_raster_until and m3924_minimap_map.texture != null:
        _position_m3924_minimap_markers(bounds, player_position, view_origin, window_cells)
        return
    m257_minimap_raster_key = raster_key
    m257_minimap_raster_until = Time.get_ticks_msec() + 2000
    var image := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
    image.fill(Color(0, 0, 0, 0))
    var source_region: Dictionary = _m3924_minimap_source_region(bounds, view_origin)
    var source_image: Image = source_region.get("image")
    var source_origin: Vector2i = source_region.get("origin", Vector2i.ZERO)
    if source_image != null:
        # Sampling is separable: calculate X/Y indices once, rather than
        # querying world discovery and doing vector/string work per pixel.
        # These are exactly the previous nearest-neighbour sample equations.
        var sample_columns := PackedInt32Array()
        for px in range(canvas_size.x):
            var u := clampf((float(px) + 0.5 - map_left) / map_diameter, 0.0, 1.0)
            var sample_x := view_origin.x + u * window_cells.x
            if centered and (sample_x < bounds.position.x or sample_x >= bounds.end.x):
                sample_columns.append(-1)
                continue
            sample_columns.append(clampi(floori(clampf(sample_x,
                float(bounds.position.x), float(bounds.end.x) - 0.0001) * SOURCE_MAP_TILE_PIXELS)
                - source_origin.x * SOURCE_MAP_TILE_PIXELS, 0, source_image.get_width() - 1))
        for py in range(canvas_size.y):
            var v := clampf((float(py) + 0.5 - map_top) / map_diameter, 0.0, 1.0)
            var sample_y := view_origin.y + v * window_cells.y
            var source_y := clampi(floori(clampf(sample_y,
                float(bounds.position.y), float(bounds.end.y) - 0.0001) * SOURCE_MAP_TILE_PIXELS)
                - source_origin.y * SOURCE_MAP_TILE_PIXELS, 0, source_image.get_height() - 1)
            var dy := float(py) + 0.5 - map_center.y
            for px in range(canvas_size.x):
                var dx := float(px) + 0.5 - map_center.x
                if dx * dx + dy * dy <= M3924_MINIMAP_MAP_RADIUS * M3924_MINIMAP_MAP_RADIUS:
                    if centered and (sample_columns[px] < 0 or sample_y < bounds.position.y or sample_y >= bounds.end.y):
                        image.set_pixel(px, py, Color(0.025, 0.035, 0.03, 1.0))
                    else:
                        image.set_pixel(px, py, source_image.get_pixel(sample_columns[px], source_y))
    else:
        for py in range(canvas_size.y):
            for px in range(canvas_size.x):
                var pixel_center: Vector2 = Vector2(float(px) + 0.5, float(py) + 0.5)
                var distance: float = pixel_center.distance_to(map_center)
                if distance > M3924_MINIMAP_MAP_RADIUS:
                    continue
                var sample_u: float = clampf((float(px) + 0.5 - map_left) / map_diameter, 0.0, 1.0)
                var sample_v: float = clampf((float(py) + 0.5 - map_top) / map_diameter, 0.0, 1.0)
                var sample_x: float = view_origin.x + sample_u * window_cells.x
                var sample_y: float = view_origin.y + sample_v * window_cells.y
                var clamped_x: int = clampi(int(floor(sample_x)), bounds.position.x, bounds.position.x + bounds.size.x - 1)
                var clamped_y: int = clampi(int(floor(sample_y)), bounds.position.y, bounds.position.y + bounds.size.y - 1)
                var cell: Vector2i = Vector2i(clamped_x, clamped_y)
                var discovered: bool = bool(world.call("is_cell_discovered", cell))
                var color: Color = Color(0.025, 0.035, 0.03, 1.0)
                if source_image != null:
                    var source_x: int = clampi(floori(clampf(sample_x,
                        float(bounds.position.x), float(bounds.end.x) - 0.0001) * SOURCE_MAP_TILE_PIXELS)
                        - source_origin.x * SOURCE_MAP_TILE_PIXELS, 0, source_image.get_width() - 1)
                    var source_y: int = clampi(floori(clampf(sample_y,
                        float(bounds.position.y), float(bounds.end.y) - 0.0001) * SOURCE_MAP_TILE_PIXELS)
                        - source_origin.y * SOURCE_MAP_TILE_PIXELS, 0, source_image.get_height() - 1)
                    color = source_image.get_pixel(source_x, source_y)
                elif discovered:
                    color = world.call("map_color_for_cell", cell)
                elif (px + py) % 2 != 0:
                    color = Color(0.045, 0.055, 0.05, 1.0)
                image.set_pixel(px, py, color)
    if m3924_minimap_map.texture is ImageTexture and m3924_minimap_map.texture.get_size() == Vector2(canvas_size):
        (m3924_minimap_map.texture as ImageTexture).update(image)
    else:
        m3924_minimap_map.texture = ImageTexture.create_from_image(image)
    m3924_minimap_draw_size = canvas_size
    m3924_minimap_draw_offset = Vector2i.ZERO
    _position_m3924_minimap_markers(bounds, player_position, view_origin, window_cells)

func _m3924_minimap_source_region(bounds: Rect2i, view_origin: Vector2) -> Dictionary:
    var interior: Image = world.interior_map_image(bounds)
    if interior != null:
        return {"image": interior, "origin": bounds.position, "bounds": bounds, "region": bounds}
    var exact_world = world.get("exact_world")
    if not bool(world.get("exact_world_mode")) or exact_world == null:
        return {}
    # Use the full MAP screen's source tile recipes in a small window around
    # the player. The margin preserves tall art crossing the window edge.
    var origin := Vector2i(floori(view_origin.x), floori(view_origin.y)) - Vector2i(3, 3)
    var end := Vector2i(ceili(view_origin.x + M3924_MINIMAP_WINDOW_CELLS.x),
        ceili(view_origin.y + M3924_MINIMAP_WINDOW_CELLS.y)) + Vector2i(3, 3)
    var needed := Rect2i(origin, end - origin)
    var world_id: int = exact_world.get_instance_id()
    var discovered_count: int = (world.get("discovered_cells") as Dictionary).size()
    var now: int = Time.get_ticks_msec()
    if world_id != m3924_minimap_cache_world_id:
        m3924_minimap_texture_images.clear()
        m3924_minimap_tile_previews.clear()
        m257_minimap_recipes.clear()
    # The picture is built for a wider area than the minimap shows and kept
    # while the view stays inside it, so walking does not rebuild it. Newly
    # discovered ground is painted in at once, but only the patch that
    # changed, not the whole picture.
    var cache_ok: bool = not m3924_minimap_source_cache.is_empty() and \
            world_id == m3924_minimap_cache_world_id and \
            now < m3924_minimap_cache_until and \
            m3924_minimap_source_cache["bounds"] == bounds and \
            (m3924_minimap_source_cache["region"] as Rect2i).encloses(needed)
    if cache_ok and discovered_count == m3924_minimap_cache_discovered:
        return m3924_minimap_source_cache
    if cache_ok:
        var kept: Rect2i = m3924_minimap_source_cache["region"]
        var first := Vector2i(2147483647, 2147483647)
        var last := Vector2i(-2147483648, -2147483648)
        var seen: Dictionary = m3924_minimap_cache_seen
        for y in range(kept.size.y):
            for x in range(kept.size.x):
                var local := Vector2i(x, y)
                if seen.has(local): continue
                var cell := kept.position + local
                if bounds.has_point(cell) and world.is_cell_discovered(cell):
                    seen[local] = true
                    first = Vector2i(mini(first.x, x), mini(first.y, y))
                    last = Vector2i(maxi(last.x, x), maxi(last.y, y))
        m3924_minimap_cache_discovered = discovered_count
        if first.x > last.x:
            return m3924_minimap_source_cache
        # Art can reach three tiles past its own (tall trees), so the patch is
        # drawn with that much surround and only its middle is copied in.
        var patch := Rect2i(first, last - first + Vector2i.ONE).grow(3).intersection(Rect2i(Vector2i.ZERO, kept.size))
        if patch.get_area() * 2 < kept.get_area():
            var drawn := patch.grow(3).intersection(Rect2i(Vector2i.ZERO, kept.size))
            var fresh := _m3924_minimap_render(Rect2i(kept.position + drawn.position, drawn.size), bounds, exact_world)
            (m3924_minimap_source_cache["image"] as Image).blit_rect(fresh,
                Rect2i((patch.position - drawn.position) * SOURCE_MAP_TILE_PIXELS, patch.size * SOURCE_MAP_TILE_PIXELS),
                patch.position * SOURCE_MAP_TILE_PIXELS)
            return m3924_minimap_source_cache
    var region := needed.grow(6)
    origin = region.position
    var image := _m3924_minimap_render(region, bounds, exact_world)
    m3924_minimap_cache_seen = {}
    for y in range(region.size.y):
        for x in range(region.size.x):
            var cell := region.position + Vector2i(x, y)
            if bounds.has_point(cell) and world.is_cell_discovered(cell):
                m3924_minimap_cache_seen[Vector2i(x, y)] = true
    m3924_minimap_cache_world_id = world_id
    m3924_minimap_cache_discovered = discovered_count
    m3924_minimap_cache_until = now + 2000
    m3924_minimap_source_cache = {
        "image": image, "origin": origin, "region": region, "bounds": bounds
    }
    return m3924_minimap_source_cache

## Draws the minimap's source picture for `region` (in tiles): every
## discovered tile, the buildings on them, and the checker over the rest.
func _m3924_minimap_render(region: Rect2i, bounds: Rect2i, exact_world) -> Image:
    var image := Image.create(region.size.x * SOURCE_MAP_TILE_PIXELS,
        region.size.y * SOURCE_MAP_TILE_PIXELS, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.025, 0.035, 0.03, 1.0))
    var cells: Array[Vector2i] = []
    var tiles: Array[SourceTile] = []
    var hidden_cells: Array[Vector2i] = []
    for y in range(region.size.y):
        for x in range(region.size.x):
            var local := Vector2i(x, y)
            var cell := region.position + local
            if not bounds.has_point(cell) or not world.is_cell_discovered(cell):
                hidden_cells.append(local)
                continue
            var tile: SourceTile = exact_world.tile_at(cell)
            if tile != null:
                cells.append(local)
                tiles.append(tile)
    for upper_pass in [false, true]:
        for index in range(cells.size()):
            var tile := tiles[index]
            var key := "%s|%s|%s|%s" % [tile.name, tile.name_upper, tile.color, upper_pass]
            if not m257_minimap_recipes.has(key):
                if m257_minimap_recipes.size() >= 4096:
                    m257_minimap_recipes.clear()
                var spec: Dictionary = SourceWorldData.render_spec(tile, upper_pass)
                var recipe: Dictionary = {}
                var texture := spec.get("texture") as Texture2D
                if texture != null:
                    var source: Image = texture.get_image()
                    var rect: Rect2 = spec.get("region", Rect2(0,0,16,16))
                    var preview := source.get_region(Rect2i(rect))
                    preview.resize(maxi(1,roundi(rect.size.x / 4.0)), maxi(1,roundi(rect.size.y / 4.0)), Image.INTERPOLATE_NEAREST)
                    recipe = {"image":preview,"rect":Rect2i(Vector2i.ZERO,preview.get_size()),
                        "offset":Vector2i((Vector2(spec.get("offset",Vector2.ZERO)) / 4.0).round())}
                m257_minimap_recipes[key] = recipe
            var recipe: Dictionary = m257_minimap_recipes[key]
            if not recipe.is_empty():
                image.blend_rect(recipe.image, recipe.rect, cells[index] * SOURCE_MAP_TILE_PIXELS + recipe.offset)
    _paint_built_structures_on_map(image, region.position)
    # Mask after both passes, preserving tall-art overlap and checker positions.
    for local in hidden_cells:
        var cell := region.position + local - bounds.position
        var shade := Color(0.025, 0.035, 0.03, 1.0)
        if (cell.x + cell.y) % 2 != 0:
            shade = Color(0.045, 0.055, 0.05, 1.0)
        image.fill_rect(Rect2i(local * SOURCE_MAP_TILE_PIXELS,
            Vector2i.ONE * SOURCE_MAP_TILE_PIXELS), shade)
    return image

var built_map_art_cache: Dictionary = {}
var m3924_minimap_cache_built := 0
var m3924_minimap_cache_seen: Dictionary = {}

func _paint_built_structures_on_map(image: Image, origin: Vector2i) -> void:
    var structures: Dictionary = world.get("built_structures")
    var visible_rect := Rect2i(origin, image.get_size() / SOURCE_MAP_TILE_PIXELS)
    var ordered: Array = structures.keys()
    ordered.sort_custom(func(a, b): return a.y < b.y if a.y != b.y else a.x < b.x)
    for cell in ordered:
        if not visible_rect.grow(4).has_point(cell): continue
        var actor := structures[cell].get("sprite") as Sprite2D
        if not is_instance_valid(actor) or actor.texture == null: continue
        var cache_key := str([actor.texture.get_instance_id(), actor.region_enabled, actor.region_rect, actor.hframes, actor.vframes, actor.frame])
        if not built_map_art_cache.has(cache_key):
            if built_map_art_cache.size() >= 512: built_map_art_cache.clear()
            var pixels := actor.texture.get_image()
            if actor.region_enabled: pixels = pixels.get_region(Rect2i(actor.region_rect))
            elif actor.hframes > 1 or actor.vframes > 1:
                var frame_size := pixels.get_size() / Vector2i(actor.hframes, actor.vframes)
                pixels = pixels.get_region(Rect2i(actor.frame_coords * frame_size, frame_size))
            var full_size := pixels.get_size()
            pixels.resize(maxi(1, roundi(full_size.x / 4.0)), maxi(1, roundi(full_size.y / 4.0)), Image.INTERPOLATE_NEAREST)
            built_map_art_cache[cache_key] = {"image":pixels,"size":full_size}
        var recipe: Dictionary = built_map_art_cache[cache_key]
        var pixels: Image = recipe.image
        var at := actor.position + actor.offset
        if actor.centered: at -= Vector2(recipe.size) * 0.5
        image.blend_rect(pixels, Rect2i(Vector2i.ZERO, pixels.get_size()), Vector2i((at / 4.0).round()) - origin * SOURCE_MAP_TILE_PIXELS)

func _position_m3924_minimap_markers(
        bounds: Rect2i, player_position: Vector2, view_origin: Vector2,
        window_cells: Vector2 = M3924_MINIMAP_WINDOW_CELLS) -> void:
    if bounds.size.x <= 0 or bounds.size.y <= 0:
        return
    var canvas_size: Vector2 = Vector2(M3924_MINIMAP_MAP_SIZE)
    var map_center: Vector2 = M3924_MINIMAP_MAP_OFFSET + canvas_size * 0.5
    var map_diameter: float = M3924_MINIMAP_MAP_RADIUS * 2.0
    var map_left: float = map_center.x - M3924_MINIMAP_MAP_RADIUS
    var map_top: float = map_center.y - M3924_MINIMAP_MAP_RADIUS
    m3924_minimap_player.position = map_center - m3924_minimap_player.size * 0.5
    var respawn: Vector2i = world.get("respawn_cell")
    m3924_minimap_respawn.visible = false
    if respawn.x > -2147483648 and bounds.has_point(respawn):
        var respawn_center: Vector2 = Vector2(
            map_left + ((float(respawn.x) + 0.5 - view_origin.x) / window_cells.x) * map_diameter,
            map_top + ((float(respawn.y) + 0.5 - view_origin.y) / window_cells.y) * map_diameter)
        var inside_circle: bool = respawn_center.distance_to(map_center) <= M3924_MINIMAP_MAP_RADIUS
        m3924_minimap_respawn.visible = inside_circle
        if m3924_minimap_respawn.visible:
            m3924_minimap_respawn.position = respawn_center - m3924_minimap_respawn.size * 0.5
            m3924_minimap_respawn.set_meta("unrotated_position", m3924_minimap_respawn.position)
    _position_minimap_other_players(map_left, map_top, map_diameter, map_center, view_origin, window_cells)

## Other players in this area, drawn like the local player's own marker.
var m3924_minimap_others: Dictionary = {}
var map_other_markers: Array = []

func _coop_players_here() -> Dictionary:
    var result := {}
    if not is_instance_valid(coop_game) or not coop_game.active or not coop_game.session.trusted:
        return result
    var packets: Dictionary = coop_game.visuals.last_packets
    for actor in packets:
        var packet: Dictionary = packets[actor]
        if actor == coop_game.session.actor or packet.get("area") != coop_game._area():
            continue
        if not packet.get("visual") is Dictionary:
            continue
        result[actor] = packet
    return result

func _coop_marker_texture(visual: Dictionary) -> AtlasTexture:
    var model := clampi(int(visual.get("model", 0)), 0, PLAYER_MODEL_WALK_TEXTURES.size() - 1)
    var color := clampi(int(visual.get("color", 0)), 0, PLAYER_COLOR_VALUES.size() - 1)
    var marker_frame := AtlasTexture.new()
    marker_frame.atlas = _recolor_texture(PLAYER_MODEL_WALK_TEXTURES[model],
        PLAYER_MODEL_REPLACE_COLORS[model], PLAYER_COLOR_VALUES[color],
        "coop:%d:%d:%s:%s" % [model, color, false, "walk"])
    marker_frame.region = Rect2(0.0, 0.0, 16.0, 11.0)
    marker_frame.set_meta("look", "%d:%d" % [model, color])
    return marker_frame

func _position_minimap_other_players(map_left: float, map_top: float, map_diameter: float,
        map_center: Vector2, view_origin: Vector2, window_cells: Vector2) -> void:
    var here := _coop_players_here()
    for actor in here:
        var packet: Dictionary = here[actor]
        var marker: TextureRect = m3924_minimap_others.get(actor)
        if not is_instance_valid(marker):
            marker = _source_texture_rect(m3924_minimap_root, "OtherPlayer", Vector2.ZERO, Vector2(7.0, 5.0), null)
            marker.z_index = 4
            m3924_minimap_others[actor] = marker
        var visual: Dictionary = packet.visual
        var look := "%d:%d" % [int(visual.get("model", 0)), int(visual.get("color", 0))]
        if marker.texture == null or marker.texture.get_meta("look", "") != look:
            marker.texture = _coop_marker_texture(visual)
        var cell: Vector2 = world.outdoor_map_position(Vector2(float(packet.get("body_x", 0.0)), float(packet.get("body_y", 0.0))) / 16.0)
        var center := Vector2(
            map_left + ((cell.x - view_origin.x) / window_cells.x) * map_diameter,
            map_top + ((cell.y - view_origin.y) / window_cells.y) * map_diameter)
        marker.visible = center.distance_to(map_center) <= M3924_MINIMAP_MAP_RADIUS
        marker.position = center - marker.size * 0.5
    for actor in m3924_minimap_others.keys():
        if not here.has(actor):
            if is_instance_valid(m3924_minimap_others[actor]):
                m3924_minimap_others[actor].queue_free()
            m3924_minimap_others.erase(actor)

func _add_map_other_players(map_view: Control, bounds: Rect2i, image_size: Vector2i, marker_size: Vector2) -> void:
    map_other_markers.clear()
    var here := _coop_players_here()
    for actor in here:
        var packet: Dictionary = here[actor]
        var other := TextureRect.new()
        other.mouse_filter = Control.MOUSE_FILTER_IGNORE
        other.texture = _coop_marker_texture(packet.visual)
        other.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        other.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        other.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        other.z_index = 19
        var cell: Vector2i = Vector2i(world.outdoor_map_position(Vector2(floorf(float(packet.get("body_x", 0.0)) / 16.0), floorf(float(packet.get("body_y", 0.0)) / 16.0))).floor())
        var center := Vector2(float(cell.x - bounds.position.x) * SOURCE_MAP_TILE_PIXELS,
            float(cell.y - bounds.position.y) * SOURCE_MAP_TILE_PIXELS)
        other.position = Vector2(
            clampf(center.x - marker_size.x * 0.5, 0.0, maxf(0.0, float(image_size.x) - marker_size.x)),
            clampf(center.y - marker_size.y * 0.5, 0.0, maxf(0.0, float(image_size.y) - marker_size.y)))
        other.size = marker_size
        other.pivot_offset = marker_size * 0.5
        map_view.add_child(other)
        map_other_markers.append(other)

func _setup_options() -> void:
    options_menu = preload("res://scripts/options_menu.gd").new()
    $UI.add_child(options_menu)
    options_menu.configure(self)
    pokedex_menu = preload("res://scripts/pokedex_menu.gd").new()
    $UI.add_child(pokedex_menu)
    pokedex_menu.configure(self)
    show_touch.get_parent().get_node("Title").text = "CONTROLS"
    game_menu_box.position = Vector2(214, 7)
    game_menu_box.size = Vector2(102, 166)
    for child in game_menu_box.get_children():
        if child != game_menu_cursor: child.hide()
    for index in range(GAME_MENU_OPTIONS.size()):
        _source_ui_label(game_menu_box,"Option%d" % index,Vector2(28,11+index*17),Vector2(68,17),11,GAME_MENU_OPTIONS[index])
    _apply_game_options()
    _update_game_menu_cursor()
    _route_existing_audio(self)

func _route_existing_audio(node: Node) -> void:
    if node is AudioStreamPlayer: GameOptions.route_audio(node)
    for child in node.get_children(): _route_existing_audio(child)

func _apply_game_options() -> void:
    GameOptions.apply_audio()
    if is_instance_valid(world.environment_system): world.environment_system.apply_music_pack()
    preload("res://scripts/emote_style.gd").refresh_tree(get_tree())
    for marker in get_tree().get_nodes_in_group("styled_held_emotes"):
        marker.texture = preload("res://scripts/held_item_emote.gd").texture()
    touch_controls.set_button_layout(int(GameOptions.values.button_layout))
    input_router.set_button_layout(int(GameOptions.values.button_layout))
    input_router.diagonal_enabled = GameOptions.enabled("diagonal")
    input_router.auto_run_enabled = GameOptions.enabled("auto_run")
    if not GameOptions.enabled("radial") and field_move_wheel_open: _close_field_move_wheel(false)
    if not GameOptions.enabled("zoom"):
        world.camera_zoom_level = 1.0
        world.player.camera.zoom = Vector2.ONE
        map_zoom = DEFAULT_MAP_ZOOM
    if not GameOptions.enabled("minimap") and is_instance_valid(m3924_minimap_root): m3924_minimap_root.hide()
    if is_instance_valid(waypoint_ui):
        if not GameOptions.enabled("map_waypoint") and waypoint_ui.naming: waypoint_ui.cancel_name()
        waypoint_ui.rebuild_markers()
        waypoint_ui.update_minimap(0.0)
    GameOptions.refresh_frames($UI)
    if is_instance_valid(dark_mode_ui): dark_mode_ui.set_enabled(GameOptions.enabled("dark_mode"))
    if not source_effect_playing: _restore_battle_background()
    minimap_frame_type = -1
    _refresh_minimap_frame()

func _classic_dialogue_style() -> StyleBoxTexture:
    return GameOptions.style()

func _source_ui_label(parent: Node, node_name: String, at: Vector2,
        dimensions: Vector2, font_size: int, initial_text: String = "",
        use_symbol_font: bool = false) -> Label:
    var label := Label.new()
    label.name = node_name
    label.position = at
    label.size = dimensions
    label.text = initial_text
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_override("font", SYMBOL_FONT if use_symbol_font else JOHTO_FONT)
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color.BLACK)
    parent.add_child(label)
    return label

func _align_menu_tick(marker: Control, row: Label, line_index: int = 0) -> void:
    # Center the native 5x7 tick on the eight-pixel Johto capital glyphs.
    # Symbol-font baselines differ from the bitmap font used by the words.
    if marker is Label:
        marker.text = ""
        if not marker.has_node("PixelTick"):
            # In dark mode the shared cursor holds its recoloured texture; a tick
            # must start from the original or dark mode recolours it twice.
            _source_texture_rect(marker, "PixelTick", Vector2.ZERO,
                Vector2(5, 7), source_command_cursor.get_meta("tick_source", source_command_cursor.texture))
    var font_size := row.get_theme_font_size("font_size")
    var line_height := row.get_theme_font("font").get_height(font_size)
    var top := row.position.y
    if row.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
        top += (row.size.y - line_height) / 2.0
    elif row.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
        top += row.size.y - line_height
    marker.position.y = roundf(top + line_index * (line_height + row.get_theme_constant("line_spacing")) + 4.0 * float(font_size) / 10.0 - 3.5)

func _align_control_tick(marker: Control, row: Control) -> void:
    var font_size := row.get_theme_font_size("font_size")
    var line_height := row.get_theme_font("font").get_height(font_size)
    var top := row.global_position.y
    if row is Button:
        var style := row.get_theme_stylebox("normal")
        var above := style.get_margin(SIDE_TOP)
        var below := style.get_margin(SIDE_BOTTOM)
        top += above + (row.size.y-above-below-line_height)*0.5
    elif row is Label:
        if row.vertical_alignment == VERTICAL_ALIGNMENT_CENTER: top += (row.size.y-line_height)*0.5
        elif row.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM: top += row.size.y-line_height
    marker.global_position.y = roundf(top+4.0*font_size/10.0-marker.size.y*0.5)

func _source_texture_rect(parent: Node, node_name: String, at: Vector2,
        dimensions: Vector2, texture: Texture2D = null) -> TextureRect:
    var rect := TextureRect.new()
    rect.name = node_name
    rect.position = at
    rect.size = dimensions
    rect.texture = texture
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(rect)
    return rect

func _configure_clean_item_pocket_layout() -> void:
    # Draw this menu at the native 320x180 viewport size.  The old 160x144
    # plate was scaled 2x horizontally and 1.25x vertically, which distorted
    # both the Johto glyphs and the selection arrow.
    item_pocket_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    item_pocket_menu.scale = Vector2.ONE
    item_pocket_menu.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    item_pocket_menu.get_node("Background").visible = false

    var backdrop := ColorRect.new()
    backdrop.name = "CleanBackdrop"
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.color = Color.WHITE
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    item_pocket_menu.add_child(backdrop)
    item_pocket_menu.move_child(backdrop, 0)

    var pocket_frame := Panel.new()
    pocket_frame.name = "PocketFrame"
    pocket_frame.position = Vector2(4, 2)
    pocket_frame.size = Vector2(82, 123)
    pocket_frame.add_theme_stylebox_override("panel", _classic_dialogue_style())
    pocket_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    item_pocket_menu.add_child(pocket_frame)
    item_pocket_menu.move_child(pocket_frame, 2)

    var list_frame := Panel.new()
    list_frame.name = "ListFrame"
    list_frame.position = Vector2(84, 2)
    list_frame.size = Vector2(232, 123)
    list_frame.add_theme_stylebox_override("panel", _classic_dialogue_style())
    list_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    item_pocket_menu.add_child(list_frame)
    item_pocket_menu.move_child(list_frame, 3)

    var description_frame := Panel.new()
    description_frame.name = "DescriptionFrame"
    description_frame.position = Vector2(4, 123)
    description_frame.size = Vector2(312, 55)
    description_frame.add_theme_stylebox_override("panel", _classic_dialogue_style())
    description_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    item_pocket_menu.add_child(description_frame)
    item_pocket_menu.move_child(description_frame, 4)

    item_pocket_label.position = Vector2(24, 14)
    item_pocket_label.size = Vector2(41, 24)
    item_pocket_label.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    item_pocket_bag.position = Vector2(24, 57)
    item_pocket_bag.size = Vector2(41, 26)
    item_pocket_bag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    item_pocket_cursor.position = Vector2(94, 13)
    item_pocket_cursor.size = Vector2(4, 7)
    item_pocket_list.position = Vector2(105, 9)
    item_pocket_list.size = Vector2(154, 88)
    item_pocket_list.add_theme_font_size_override("font_size", 9)
    item_pocket_list.add_theme_constant_override("line_spacing", 6)
    item_pocket_quantities.position = Vector2(260, 9)
    item_pocket_quantities.size = Vector2(46, 88)
    item_pocket_quantities.add_theme_font_size_override("font_size", 9)
    item_pocket_quantities.add_theme_constant_override("line_spacing", 6)
    item_pocket_description.position = Vector2(16, 134)
    item_pocket_description.size = Vector2(288, 34)
    item_pocket_description.add_theme_font_size_override("font_size", 9)
    item_pocket_description.add_theme_constant_override("line_spacing", 2)

func _configure_wide_single_battle_layout() -> void:
    # Keep every source HUD element uniformly scaled, then move the enemy
    # group left and the player group right.  This fills the 16:9 viewport
    # without widening individual pixels or warping the Johto font.
    const ENEMY_SHIFT = -40.0
    const PLAYER_SHIFT = 40.0
    for node_name in ["EnemyFrame", "EnemyLevelChar", "EnemyName",
            "EnemyLevel", "EnemyStatus", "EnemyGender", "EnemyHPTrack", "EnemyHPFill"]:
        var node = source_single_hud.get_node(node_name) as Control
        node.position.x += ENEMY_SHIFT
    for node_name in ["PlayerFrame", "PlayerLevelChar", "PlayerName",
            "PlayerLevel", "PlayerStatus", "PlayerGender", "PlayerHPTrack", "PlayerHPFill",
            "PlayerHPCurrent", "PlayerHPMax", "EXPFill"]:
        var node = source_single_hud.get_node(node_name) as Control
        node.position.x += PLAYER_SHIFT

    battle_clean_command_cursor = _source_texture_rect(
        battle_actions, "CleanCommandCursor", Vector2.ZERO, Vector2(5, 7),
        source_command_cursor.texture)
    battle_clean_command_cursor.stretch_mode = TextureRect.STRETCH_SCALE
    battle_clean_command_cursor.z_index = 3
    battle_command_cursor.visible = false

func _create_party_list_row(parent: Control, row_index: int) -> Dictionary:
    # M74.3.9.11: reproduce the ORIGINAL PokeWilds party-row composition
    # from picture 2 instead of spreading every source X-coordinate across the
    # 16:9 viewport.  The 160x144 source menu has 16px rows; 1.25x vertical
    # mapping to the unchanged y=138 border gives a 19px row pitch in the existing 320x180 UI.  The left
    # cluster (cursor/sprite/name/gender/level/HP plate) keeps that same 1.25x
    # source spacing and native aspect.  ONLY the straight HP meter and its
    # right-aligned number consume the extra widescreen width.  This preserves
    # the source look without letterboxing or warping sprites/text.
    const PARTY_ROW_PITCH := 19.0
    const PARTY_RIGHT := 318.0
    const HP_TRACK_X := 130.0
    const HP_TRACK_Y := 20.0
    const HP_TRACK_H := 7.0
    const HP_RIGHT_CAP_W := 5.0
    const HP_FILL_Y := 2.0
    const HP_FILL_H := 2.0

    var row := Control.new()
    row.name = "PartyRow%d" % row_index
    row.position = Vector2(0, row_index * PARTY_ROW_PITCH)
    row.size = Vector2(320, PARTY_ROW_PITCH)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(row)

    # Source anchors from the actual PokeWilds 160px row, scaled by 1.25:
    # cursor x0, sprite x7, name x24, gender x25, level x67,
    # HP plate x88 and meter x104.  These are deliberately COMPACT.
    var cursor := _source_texture_rect(row, "Cursor", Vector2(1, 9),
        Vector2(6, 8), source_command_cursor.texture)
    cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

    var sprite := _source_texture_rect(row, "PokemonSprite", Vector2(9, 6),
        Vector2(19, 19))
    sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var held_icon := _source_texture_rect(row, "HeldItem", Vector2(9, 17), Vector2(8, 8), preload("res://assets/landmark_pokeball.png"))
    held_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    held_icon.visible = false
    var shiny_icon := _source_texture_rect(row, "ShinyIcon", Vector2(20, 17), Vector2(8, 8), preload("res://scripts/menu_symbol_palette.gd").shiny())
    shiny_icon.visible = false

    # First line: source-like name cluster on the left; HP number remains
    # flush-right above the extended meter, exactly as the source does above
    # its shorter meter.
    var name_label := _source_ui_label(row, "Name", Vector2(30, 9),
        Vector2(124, 11), 11)
    name_label.clip_text = true
    name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    var hp_value := _source_ui_label(row, "HPValue", Vector2(220, 10),
        Vector2(98, 11), 11)
    hp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

    # Second line exactly follows picture 2: gender immediately below the
    # name, then :L##, the authored gold HP: plate, and the meter on ONE line.
    var status_label := _source_ui_label(row, "Status", Vector2(30, 18),
        Vector2(27, 9), 8)
    status_label.clip_text = true
    var gender := _source_texture_rect(row, "Gender", Vector2(58, 18),
        Vector2(10, 10), SOURCE_MALE_SYMBOL)
    gender.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var level := _source_ui_label(row, "Level", Vector2(84, 20),
        Vector2(46, 10), 10)
    var hp_badge := _source_texture_rect(row, "HPBadge", Vector2(113, 20),
        Vector2(17, 7), _source_texture_region(
            SOURCE_PARTY_HEALTH_ROW, Rect2(88, 9, 16, 6)))
    hp_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

    # Recreate the source bar geometry instead of drawing a boxed rectangle.
    # Original source pixels: white trough, green/orange/red fill, one black
    # bottom rule and a four-pixel black end cap.  Widescreen merely extends
    # the straight trough; nothing with recognizable artwork is stretched.
    var hp_track := Control.new()
    hp_track.name = "HPTrack"
    hp_track.position = Vector2(HP_TRACK_X, HP_TRACK_Y)
    hp_track.size = Vector2(PARTY_RIGHT - HP_TRACK_X, HP_TRACK_H)
    hp_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(hp_track)

    var hp_bottom := ColorRect.new()
    hp_bottom.name = "BottomRule"
    hp_bottom.position = Vector2(0, HP_TRACK_H - 1)
    hp_bottom.size = Vector2(hp_track.size.x, 1)
    hp_bottom.color = Color.BLACK
    hp_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hp_track.add_child(hp_bottom)

    var hp_end_cap := ColorRect.new()
    hp_end_cap.name = "EndCap"
    hp_end_cap.position = Vector2(hp_track.size.x - HP_RIGHT_CAP_W, 0)
    hp_end_cap.size = Vector2(HP_RIGHT_CAP_W, HP_TRACK_H)
    hp_end_cap.color = Color.BLACK
    hp_end_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hp_track.add_child(hp_end_cap)

    var hp_fill := ColorRect.new()
    hp_fill.name = "Fill"
    hp_fill.position = Vector2(0, HP_FILL_Y)
    hp_fill.size = Vector2(hp_track.size.x - HP_RIGHT_CAP_W, HP_FILL_H)
    hp_fill.color = Color8(0, 184, 0)
    hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hp_track.add_child(hp_fill)

    return {
        "root":row, "cursor":cursor, "sprite":sprite, "shiny_icon":shiny_icon, "held_icon":held_icon,
        "name":name_label, "gender":gender, "status":status_label, "level":level,
        "hp_value":hp_value, "hp_fill":hp_fill,
        "hp_capacity":hp_track.size.x - HP_RIGHT_CAP_W,
        "row_index":row_index, "species":"", "is_egg":false
    }

func _hide_legacy_party_card() -> void:
    pokemon_menu_cursor.visible = false
    pokemon_menu_sprite.visible = false
    pokemon_menu_name.visible = false
    pokemon_menu_level.visible = false
    pokemon_menu_hp_value.visible = false
    pokemon_menu_hp_fill.get_parent().visible = false
    if pokemon_menu_gender != null:
        pokemon_menu_gender.visible = false

func _party_status_abbreviation(status: String) -> String:
    match status.to_upper():
        "BURN":
            return "BRN"
        "POISON":
            return "PSN"
        "PARALYSIS":
            return "PAR"
        "SLEEP":
            return "SLP"
        "FREEZE":
            return "FRZ"
    return ""

func _set_party_list_row(row_data: Dictionary, pokemon: Dictionary,
        selected: bool) -> void:
    var root := row_data["root"] as Control
    root.visible = not pokemon.is_empty()
    if pokemon.is_empty():
        row_data["species"] = ""
        row_data["is_egg"] = false
        return
    (row_data["cursor"] as TextureRect).visible = selected
    var sprite := row_data["sprite"] as TextureRect
    var name_label := row_data["name"] as Label
    var gender := row_data["gender"] as TextureRect
    var status_label := row_data["status"] as Label
    var level := row_data["level"] as Label
    var hp_value := row_data["hp_value"] as Label
    var hp_fill := row_data["hp_fill"] as ColorRect
    (row_data["shiny_icon"] as TextureRect).visible = PokemonData.is_shiny(pokemon) and not bool(pokemon.get("is_egg", false))
    (row_data["held_icon"] as TextureRect).visible = not bool(pokemon.get("is_egg", false)) and not String(pokemon.get("held_item", "")).is_empty()
    if bool(pokemon.get("is_egg", false)):
        row_data["species"] = ""
        row_data["is_egg"] = true
        sprite.texture = POKEMON_EGG_TEXTURE
        sprite.visible = true
        name_label.text = "EGG"
        name_label.scale.x = 1.0
        gender.visible = false
        status_label.text = ""
        level.text = ""
        hp_value.text = "--/--"
        hp_fill.size.x = 0.0
        return
    var record := BattleEngine.ensure_pokemon(pokemon)
    var species := String(record.get("species", "machop")).to_lower()
    row_data["species"] = species
    row_data["shiny"] = PokemonData.is_shiny(record)
    row_data["form"] = String(record.get("form", ""))
    row_data["is_egg"] = false
    sprite.texture = _party_record_frame(row_data)
    sprite.visible = sprite.texture != null
    _set_fitting_pokemon_name(name_label, record)
    status_label.text = _party_status_abbreviation(String(record.get("status", "")))
    level.text = ":L%d" % int(record.get("level", 1))
    # The bitmap font advances eight pixels even at this label's font size.
    # Fit the complete level before the shifted badge, including level 100.
    var level_width := level.get_theme_font("font").get_string_size(
        level.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
    level.scale.x = minf(1.0, 28.0 / maxf(1.0, level_width))
    _set_source_gender(gender, record)
    var hp := int(record.get("hp", 0))
    var max_hp := maxi(1, int(record.get("max_hp", 1)))
    var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
    hp_value.text = "%d/%d" % [hp, max_hp]
    var hp_capacity := float(row_data.get("hp_capacity", 100.0))
    hp_fill.size.x = _battle_hp_width(ratio, hp_capacity)
    hp_fill.color = _battle_hp_color(ratio)

func _refresh_party_list_rows(rows: Array[Dictionary], party: Array,
        selected_index: int) -> void:
    for row_index in range(rows.size()):
        var pokemon: Dictionary = {}
        if row_index < mini(6, party.size()) and \
                typeof(party[row_index]) == TYPE_DICTIONARY:
            pokemon = party[row_index] as Dictionary
        _set_party_list_row(rows[row_index], pokemon, row_index == selected_index)

func _refresh_party_sprite_frames(rows: Array[Dictionary]) -> void:
    for row_data in rows:
        var species := String(row_data.get("species", ""))
        if species.is_empty():
            continue
        var sprite := row_data.get("sprite") as TextureRect
        if sprite == null or not sprite.visible:
            continue
        sprite.texture = _party_record_frame(row_data)

func _update_party_sprite_animation(delta: float) -> void:
    var overworld_party_visible := (
        pokemon_menu_open and pokemon_menu != null and pokemon_menu.visible)
    var battle_party_visible := (
        battle_party_view != null and battle_party_view.visible)
    if not overworld_party_visible and not battle_party_visible and not storage_menu_open:
        party_sprite_animation_elapsed = 0.0
        return
    party_sprite_animation_elapsed += delta
    if party_sprite_animation_elapsed < 0.30:
        return
    party_sprite_animation_elapsed = fmod(party_sprite_animation_elapsed, 0.30)
    party_sprite_animation_frame = (party_sprite_animation_frame + 1) & 1
    if overworld_party_visible:
        _refresh_party_sprite_frames(pokemon_party_rows)
    if battle_party_visible:
        _refresh_party_sprite_frames(battle_party_rows)
    if storage_menu_open:
        _refresh_party_sprite_frames(storage_rows)

func _build_m66_source_ui() -> void:
    _configure_clean_item_pocket_layout()
    _configure_wide_single_battle_layout()
    setup_go_cursor = _source_texture_rect(setup_panel, "GoCursor",
        Vector2.ZERO, Vector2(6, 8), source_command_cursor.texture)
    setup_go_cursor.stretch_mode = TextureRect.STRETCH_SCALE
    setup_go_cursor.visible = false
    # Source-style save selector shown before a saved world is loaded.
    setup_load_panel = Control.new()
    setup_load_panel.name = "SourceLoadSelector"
    setup_load_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    setup_load_panel.z_index = 340
    $UI.add_child(setup_load_panel)
    var load_backdrop = ColorRect.new()
    load_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    load_backdrop.color = Color.WHITE
    load_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    setup_load_panel.add_child(load_backdrop)
    var load_frame = Panel.new()
    load_frame.name = "LoadFrame"
    load_frame.position = Vector2(16, 14)
    load_frame.size = Vector2(288, 152)
    load_frame.add_theme_stylebox_override("panel", _classic_dialogue_style())
    setup_load_panel.add_child(load_frame)
    var load_title = _source_ui_label(load_frame, "Title", Vector2(20, 17),
        Vector2(248, 18), 12, "LOAD GAME")
    load_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _source_ui_label(load_frame, "Previous", Vector2(32, 65),
        Vector2(10, 12), 9, "◀", true)
    setup_load_name = _source_ui_label(load_frame, "SaveName", Vector2(48, 62),
        Vector2(192, 16), 10, "default.sav")
    setup_load_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    setup_load_name.clip_text = true
    setup_load_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _source_ui_label(load_frame, "Next", Vector2(246, 65),
        Vector2(10, 12), 9, "▶", true)
    _source_ui_label(load_frame, "GoCursor", Vector2(108, 101),
        Vector2(7, 10), 7, "▶", true)
    _source_ui_label(load_frame, "Go", Vector2(117, 102),
        Vector2(55, 15), 11, "Go!")
    _align_menu_tick(load_frame.get_node("GoCursor"), load_frame.get_node("Go"))
    _align_menu_tick(load_frame.get_node("Previous"), setup_load_name)
    _align_menu_tick(load_frame.get_node("Next"), setup_load_name)
    (load_frame.get_node("Previous/PixelTick") as TextureRect).flip_h = true

    # Source-style Pokémon storage screen.  It is deliberately created here
    # rather than replacing the existing party menu, so opening a chest cannot
    # perturb unrelated menu geometry.
    storage_menu = Control.new()
    storage_menu.name = "PokemonStorageMenu"
    storage_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    storage_menu.z_index = 345
    storage_menu.visible = false
    $UI.add_child(storage_menu)
    var storage_backdrop = ColorRect.new()
    storage_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    storage_backdrop.color = Color.WHITE
    storage_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    storage_menu.add_child(storage_backdrop)
    var storage_footer = Panel.new()
    storage_footer.position = Vector2(0, 144)
    storage_footer.size = Vector2(320, 36)
    storage_footer.add_theme_stylebox_override("panel", _classic_dialogue_style())
    storage_menu.add_child(storage_footer)
    for index in range(6):
        var row := _create_party_list_row(storage_menu, index)
        var skills := _source_ui_label(row.root,"FieldMoves",Vector2(30,19),Vector2(132,9),8)
        row["field_moves"] = skills
        row.gender.position.x = 166
        row.level.position.x = 179
        row.root.get_node("HPBadge").position.x = 211
        var track: Control = row.root.get_node("HPTrack")
        track.position.x = 228
        track.size.x = 90
        track.get_node("BottomRule").size.x = 90
        track.get_node("EndCap").position.x = 85
        row.hp_capacity = 85.0
        storage_rows.append(row)
    storage_prompt = _source_ui_label(storage_menu, "Footer",
        Vector2(16, 151), Vector2(288, 18), 11)
    storage_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    storage_actions = Panel.new()
    storage_actions.position = Vector2(96, 48)
    storage_actions.size = Vector2(224, 132)
    storage_actions.add_theme_stylebox_override("panel", _classic_dialogue_style())
    storage_menu.add_child(storage_actions)
    for index in range(7):
        storage_action_labels.append(_source_ui_label(storage_actions, "Action%d" % index,
            Vector2(24, 9 + index * 20), Vector2(126, 18), 11))
    storage_footer_arrow = _source_texture_rect(storage_menu, "PageArrow",
        Vector2(292, 153), Vector2(5, 7), source_command_cursor.texture)
    storage_cursor = _source_texture_rect(storage_actions, "Cursor",
        Vector2(10, 9), Vector2(5, 7), source_command_cursor.texture)
    storage_dialog = Panel.new()
    storage_dialog.position = Vector2(0, 126)
    storage_dialog.size = Vector2(320, 54)
    storage_dialog.add_theme_stylebox_override("panel", _classic_dialogue_style())
    storage_menu.add_child(storage_dialog)
    storage_dialog_text = _source_ui_label(storage_dialog, "Text",
        Vector2(10, 6), Vector2(300, 44), 10)
    storage_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    storage_choice_panel = Panel.new()
    storage_choice_panel.position = Vector2(240, 74)
    storage_choice_panel.size = Vector2(80, 52)
    storage_choice_panel.add_theme_stylebox_override("panel", _classic_dialogue_style())
    storage_menu.add_child(storage_choice_panel)
    storage_choice_arrow = _source_texture_rect(storage_choice_panel, "ChoiceArrow",
        Vector2(10, 12), Vector2(5, 7), source_command_cursor.texture)
    storage_choice_label = _source_ui_label(storage_choice_panel, "Choices",
        Vector2(24, 8), Vector2(48, 16), 10, "YES")
    storage_no_label = _source_ui_label(storage_choice_panel, "NoChoice",
        Vector2(24, 30), Vector2(48, 16), 10, "NO")
    storage_nickname = LineEdit.new()
    storage_nickname.position = Vector2(10, 23)
    storage_nickname.size = Vector2(290, 24)
    storage_nickname.max_length = 10
    storage_nickname.add_theme_font_override("font", JOHTO_FONT)
    storage_nickname.add_theme_font_size_override("font_size", 10)
    storage_dialog.add_child(storage_nickname)
    storage_nickname.text_changed.connect(func(value: String):
        var filtered := ""
        for character in value:
            if character in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .?!":
                filtered += character
        if filtered != value:
            var caret := storage_nickname.caret_column
            storage_nickname.text = filtered
            storage_nickname.caret_column = mini(caret, filtered.length()))
    storage_nickname.text_submitted.connect(func(_text: String):
        storage_nickname.release_focus()
        storage_mode = "CONFIRM"
        storage_pending = "NICKNAME"
        storage_yes = true
        _refresh_storage_menu())

    # Keep the MessagePanel's existing down arrow; no extra right-side arrow.
    trainer_tip_continue = null

    # Use the full viewport for both party selectors.  Keeping controls at
    # native scale makes the text readable and prevents the right-hand HP
    # values and popup entries from being clipped on Android.
    pokemon_menu_cursor.position = Vector2(4, 10)
    pokemon_menu_cursor.size = Vector2(10, 16)
    pokemon_menu_sprite.position = Vector2(20, 6)
    pokemon_menu_sprite.size = Vector2(32, 32)
    pokemon_menu_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    pokemon_menu_name.position = Vector2(58, 10)
    pokemon_menu_name.size = Vector2(130, 18)
    pokemon_menu_level.position = Vector2(150, 26)
    pokemon_menu_level.size = Vector2(44, 16)
    pokemon_menu_hp_value.position = Vector2(230, 9)
    pokemon_menu_hp_value.size = Vector2(72, 18)
    var pokemon_hp_bar = pokemon_menu_hp_fill.get_parent() as ColorRect
    pokemon_hp_bar.position = Vector2(208, 34)
    pokemon_hp_bar.size = Vector2(94, 10)
    pokemon_menu_hp_fill.position = Vector2(3, 3)
    pokemon_menu_hp_fill.size = Vector2(88, 4)
    var prompt_box = pokemon_menu_prompt.get_parent() as Panel
    prompt_box.position = Vector2(4, 138)
    prompt_box.size = Vector2(312, 40)
    pokemon_menu_prompt.position = Vector2(14, 10)
    pokemon_menu_prompt.size = Vector2(280, 18)
    pokemon_menu_gender = _source_texture_rect(pokemon_menu, "Gender",
        Vector2(62, 29), Vector2(10, 10), SOURCE_MALE_SYMBOL)
    _hide_legacy_party_card()
    for row_index in range(6):
        pokemon_party_rows.append(_create_party_list_row(pokemon_menu, row_index))
    pokemon_action_panel = Panel.new()
    pokemon_action_panel.name = "PokemonActionMenu"
    pokemon_action_panel.position = Vector2(166, 40)
    pokemon_action_panel.size = Vector2(150, 138)
    pokemon_action_panel.add_theme_stylebox_override("panel", _classic_dialogue_style())
    pokemon_menu.add_child(pokemon_action_panel)
    pokemon_action_cursor = _source_texture_rect(pokemon_action_panel, "Cursor",
        Vector2(12, 10), Vector2(5, 7), source_command_cursor.texture)
    pokemon_action_cursor.stretch_mode = TextureRect.STRETCH_SCALE
    pokemon_action_list = _source_ui_label(pokemon_action_panel, "List",
        Vector2(28, 10), Vector2(110, 116), 10)
    pokemon_action_list.add_theme_constant_override("line_spacing", 6)
    pokemon_action_panel.visible = false

    # Battle PKMN selection uses the same source party row and dialogue border.
    battle_party_view = Control.new()
    battle_party_view.name = "SourcePartyView"
    battle_party_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    battle_party_view.z_index = 10
    battle_submenu.add_child(battle_party_view)
    var battle_party_backdrop = ColorRect.new()
    battle_party_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    battle_party_backdrop.color = Color.WHITE
    battle_party_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    battle_party_view.add_child(battle_party_backdrop)
    battle_party_cursor = _source_ui_label(battle_party_view, "Cursor",
        Vector2(4, 10), Vector2(10, 16), 9, "▶", true)
    battle_party_sprite = _source_texture_rect(battle_party_view, "PokemonSprite",
        Vector2(20, 6), Vector2(32, 32))
    battle_party_name = _source_ui_label(battle_party_view, "Name",
        Vector2(58, 10), Vector2(130, 18), 10)
    battle_party_level = _source_ui_label(battle_party_view, "Level",
        Vector2(150, 26), Vector2(44, 16), 9)
    battle_party_gender = _source_texture_rect(battle_party_view, "Gender",
        Vector2(62, 29), Vector2(10, 10), SOURCE_MALE_SYMBOL)
    battle_party_hp_value = _source_ui_label(battle_party_view, "HPValue",
        Vector2(230, 9), Vector2(72, 18), 10)
    battle_party_hp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    var battle_hp_bar = ColorRect.new()
    battle_hp_bar.name = "HPBar"
    battle_hp_bar.position = Vector2(208, 34)
    battle_hp_bar.size = Vector2(94, 10)
    battle_hp_bar.color = Color.BLACK
    battle_party_view.add_child(battle_hp_bar)
    _source_ui_label(battle_hp_bar, "HPLabel", Vector2(-25, -2),
        Vector2(27, 12), 8, "HP:").add_theme_color_override(
            "font_color", Color8(240, 194, 69))
    battle_party_hp_fill = ColorRect.new()
    battle_party_hp_fill.name = "Fill"
    battle_party_hp_fill.position = Vector2(3, 3)
    battle_party_hp_fill.size = Vector2(88, 4)
    battle_party_hp_fill.color = Color8(0, 184, 0)
    battle_hp_bar.add_child(battle_party_hp_fill)
    var battle_prompt_panel = Panel.new()
    battle_prompt_panel.name = "PromptBox"
    battle_prompt_panel.position = Vector2(4, 138)
    battle_prompt_panel.size = Vector2(312, 40)
    battle_prompt_panel.add_theme_stylebox_override("panel", _classic_dialogue_style())
    battle_party_view.add_child(battle_prompt_panel)
    battle_party_prompt = _source_ui_label(battle_prompt_panel, "Prompt",
        Vector2(14, 10), Vector2(280, 18), 10, "Choose a POKEMON.")
    battle_party_action_panel = Panel.new()
    battle_party_action_panel.name = "PokemonActionMenu"
    battle_party_action_panel.position = Vector2(166, 40)
    battle_party_action_panel.size = Vector2(150, 138)
    battle_party_action_panel.add_theme_stylebox_override(
        "panel", _classic_dialogue_style())
    battle_party_view.add_child(battle_party_action_panel)
    battle_party_action_cursor = _source_texture_rect(battle_party_action_panel,
        "Cursor", Vector2(12, 10), Vector2(5, 7), source_command_cursor.texture)
    battle_party_action_cursor.stretch_mode = TextureRect.STRETCH_SCALE
    battle_party_action_list = _source_ui_label(battle_party_action_panel,
        "List", Vector2(28, 10), Vector2(110, 116), 10)
    battle_party_action_list.add_theme_constant_override("line_spacing", 6)
    battle_party_action_panel.visible = false
    battle_party_cursor.visible = false
    battle_party_sprite.visible = false
    battle_party_name.visible = false
    battle_party_level.visible = false
    battle_party_gender.visible = false
    battle_party_hp_value.visible = false
    battle_hp_bar.visible = false
    for row_index in range(6):
        battle_party_rows.append(_create_party_list_row(
            battle_party_view, row_index))
    battle_prompt_panel.move_to_front()
    battle_party_action_panel.move_to_front()

    # Three exact source stat-page plates with selected-Pokemon data layered
    # over their intended blank fields.
    pokemon_stats_overlay = Control.new()
    pokemon_stats_overlay.name = "PokemonStatsOverlay"
    pokemon_stats_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pokemon_stats_overlay.z_index = 360
    $UI.add_child(pokemon_stats_overlay)
    var stats_backdrop = ColorRect.new()
    stats_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    stats_backdrop.color = Color.WHITE
    stats_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    pokemon_stats_overlay.add_child(stats_backdrop)
    var stats_source = Control.new()
    stats_source.name = "SourceCanvas"
    stats_source.position = Vector2.ZERO
    stats_source.size = Vector2(320, 180)
    stats_source.scale = Vector2.ONE
    pokemon_stats_overlay.add_child(stats_source)
    pokemon_stats_background = _source_texture_rect(stats_source, "Background",
        Vector2.ZERO, Vector2(320, 180), SOURCE_STATS_BACKGROUNDS[0])
    pokemon_stats_background.stretch_mode = TextureRect.STRETCH_SCALE
    pokemon_stats_background.visible = false
    pokemon_stats_sprite = _source_texture_rect(stats_source, "PokemonSprite",
        Vector2(14, 8), Vector2(64, 64))
    var header_line = ColorRect.new()
    header_line.name = "HeaderDivider"
    header_line.position = Vector2(0, 76)
    header_line.size = Vector2(320, 4)
    header_line.color = Color.WHITE
    stats_source.add_child(header_line)
    pokemon_stats_header_left = _source_ui_label(stats_source, "HeaderLeft",
        Vector2(112, 4), Vector2(72, 14), 9)
    pokemon_stats_header_right = _source_ui_label(stats_source, "HeaderRight",
        Vector2(228, 4), Vector2(48, 14), 10)
    pokemon_stats_header_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    pokemon_stats_gender = _source_texture_rect(stats_source, "Gender",
        Vector2(286, 4), Vector2(10, 10), SOURCE_MALE_SYMBOL)
    pokemon_stats_shiny = _source_texture_rect(stats_source, "Shiny",
        Vector2(70, 64), Vector2(8, 8), preload("res://scripts/menu_symbol_palette.gd").shiny())
    pokemon_stats_shiny.visible = false
    _pokemon_stat_field(stats_source, "Name", Vector2(112, 25), Vector2(180, 18), 12)
    _source_ui_label(stats_source, "Slash", Vector2(142, 48),
        Vector2(12, 12), 9, "/")
    var tab_colors = [Color8(248, 152, 248), Color8(176, 248, 104),
        Color8(136, 240, 240)]
    for tab_index in range(3):
        var tab_border = ColorRect.new()
        tab_border.name = "Tab%dBorder" % tab_index
        tab_border.position = Vector2(204 + tab_index * 36, 47)
        tab_border.size = Vector2(24, 24)
        tab_border.color = Color.BLACK
        stats_source.add_child(tab_border)
        var tab = ColorRect.new()
        tab.name = "Tab%d" % tab_index
        tab.position = Vector2(3, 3)
        tab.size = Vector2(18, 18)
        tab.color = tab_colors[tab_index]
        tab_border.add_child(tab)
        pokemon_stats_tabs.append(tab)
        var tick = _source_ui_label(tab_border, "Tick", Vector2(5, 3),
            Vector2(14, 14), 9, "▼", true)
        tick.add_theme_color_override("font_color", Color.WHITE)
        pokemon_stats_tab_ticks.append(tick)
    _build_pokemon_stats_pages(stats_source)
    progression_level_dialogue = Panel.new()
    progression_level_dialogue.name = "LevelUpDialogueBorder"
    progression_level_dialogue.position = Vector2(4, 121)
    progression_level_dialogue.size = Vector2(312, 57)
    progression_level_dialogue.add_theme_stylebox_override(
        "panel", _classic_dialogue_style())
    progression_level_dialogue.z_index = 1
    progression_overlay.add_child(progression_level_dialogue)
    progression_level_message = _source_ui_label(
        progression_level_dialogue, "LevelUpMessage", Vector2(12, 10),
        Vector2(282, 32), 10)
    progression_level_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    progression_level_message.clip_text = true
    progression_level_dialogue.visible = false
    progression_stats_frame = Panel.new()
    progression_stats_frame.name = "LevelUpStatsBorder"
    progression_stats_frame.position = Vector2(142, 0)
    progression_stats_frame.size = Vector2(178, 121)
    progression_stats_frame.add_theme_stylebox_override("panel", _classic_dialogue_style())
    progression_stats_frame.z_index = 2
    progression_overlay.add_child(progression_stats_frame)
    for index in range(5):
        var stat_name = _source_ui_label(progression_stats_frame, "Stat%d" % index,
            Vector2(16, 7 + index * 20), Vector2(108, 13), 10,
            ["ATTACK", "DEFENSE", "SPCL.ATK", "SPCL.DEF", "SPEED"][index])
        stat_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var value = _source_ui_label(progression_stats_frame, "Value%d" % index,
            Vector2(132, 7 + index * 20), Vector2(32, 13), 10)
        value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        progression_stats_fields.append(value)
    progression_stats_frame.visible = false
    progression_hint.z_index = 2
    progression_list.z_index = 2
    progression_values.z_index = 2
    progression_sprite_top.z_index = 2
    _create_progression_menu_frames()

var fps_label: Label
var fps_refresh := 0.0

## OPTIONS > FPS COUNTER: frames drawn per second, top right.
func _update_fps_counter(delta: float) -> void:
    if not GameOptions.enabled("fps_counter") or not started:
        if is_instance_valid(fps_label): fps_label.hide()
        return
    if not is_instance_valid(fps_label):
        fps_label = _source_ui_label(get_node("UI"), "FpsCounter", Vector2.ZERO, Vector2(40, 10), 8)
        fps_label.anchor_left = 1.0
        fps_label.anchor_right = 1.0
        fps_label.offset_left = -46
        fps_label.offset_right = -4
        fps_label.offset_top = 3
        fps_label.offset_bottom = 13
        fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        fps_label.z_index = 300
        # White with a dark edge, so it reads over any ground.
        fps_label.add_theme_color_override("font_color", Color.WHITE)
        fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
        fps_label.add_theme_constant_override("outline_size", 3)
        fps_refresh = 0.0
    fps_label.show()
    fps_refresh -= delta / maxf(Engine.time_scale, 0.01)
    if fps_refresh <= 0.0:
        fps_refresh = 0.25
        fps_label.text = str(roundi(Engine.get_frames_per_second()))

func _process(delta: float) -> void:
    _update_fps_counter(delta)
    map_cache_check_time -= delta
    if started and world.generated and not generating and not map_cache_warming and not map_building and map_cache_check_time <= 0.0:
        map_cache_check_time = 0.5
        _warm_map_cache()

    _poll_android_back_bridge()
    if is_instance_valid(edge_sky):
        var flying_overworld: bool = world.active_field_move in ["FLY", "SURF"] and world.active_area_id == "OVERWORLD"
        if edge_sky.visible and not flying_overworld:
            world._configure_camera()
        edge_sky.visible = flying_overworld
    _update_field_move_wheel_input()
    _update_m3924_dig_hud_and_minimap(delta)
    _update_party_sprite_animation(delta)
    _update_battle_sprite_animation(delta)
    _stop_fainted_active_field_move()
    _update_sleeping_bag_rest(delta)

    if build_menu_open:
        if String(world.get("active_field_move")) != "BUILD":
            build_menu_open = false
            build_panel.visible = false
        elif not CraftingData.build_recipes().is_empty():
            var world_build_index := int(world.call("get_build_selection_index"))
            if world_build_index != build_menu_index:
                build_menu_index = world_build_index
                _apply_build_hud_selection()

    if generating:
        generation_tip_timer -= delta
        if generation_tip_timer <= 0.0:
            _show_generation_tip()

    if resource_popup_timer > 0.0:
        resource_popup_timer -= delta
        if resource_popup_timer <= 0.0:
            resource_popup.visible = false

    if game_menu_open and game_menu_detail_open and game_menu_map_screen.visible and not teleport_map_mode:
        world.set_gameplay_enabled(false)
        if is_instance_valid(waypoint_ui):waypoint_ui.move_cursor(delta)

    if message_label.text != message_reveal_text:
        message_label.visible_characters = -1
    if message_timer > 0.0:
        if message_label.visible_characters >= 0:
            message_reveal_elapsed += delta
            message_label.visible_characters = mini(message_label.text.length(),int(message_reveal_elapsed * GameOptions.text_multiplier() / BATTLE_TEXT_CHAR_DELAY))
        message_timer -= delta
        if message_timer <= 0.0:
            message_panel.visible = false

    if menu_nav_cooldown > 0.0:
        menu_nav_cooldown = max(0.0, menu_nav_cooldown - delta)

    if battle_text_busy:
        battle_text_accumulator += delta * GameOptions.text_multiplier()
        var characters_to_add := int(battle_text_accumulator / BATTLE_TEXT_CHAR_DELAY)
        if characters_to_add > 0:
            battle_text_accumulator -= float(characters_to_add) * BATTLE_TEXT_CHAR_DELAY
            battle_status.visible_characters = mini(
                battle_text_full.length(), battle_status.visible_characters + characters_to_add)
            if battle_status.visible_characters >= battle_text_full.length():
                _finish_battle_text()

func _update_field_move_wheel_input() -> void:
    if Input.is_action_pressed("ball_mechanics") or _field_move_wheel_stick().length()>=0.35:
        field_quick_tap_at=-1
    if not is_instance_valid(ball_mechanics):
        ball_mechanics = preload("res://scripts/ball_mechanics.gd").new()
        ball_mechanics.main = self
        add_child(ball_mechanics)
    if ball_mechanics.update_input(): return
    var trigger_held := Input.is_action_pressed("field_move_wheel")
    if field_wheel_wait_for_release:
        if not trigger_held: field_wheel_wait_for_release = false
        return
    if not field_move_wheel_open:
        if trigger_held and _can_open_field_move_wheel():
            _open_field_move_wheel()
        return
    if _field_ui_blocks_gameplay(build_wheel_mode):
        _close_field_move_wheel(false)
        return
    if trigger_held:
        var stick := _field_move_wheel_stick()
        if stick.length() >= 0.35:
            var angle_from_top := fposmod(atan2(stick.y, stick.x) + PI * 0.5, TAU)
            var count := field_move_wheel.entries.size()
            if count == 0: return
            var step := TAU / float(count)
            field_move_wheel_index = posmod(
                int(floor((angle_from_top + step * 0.5) / step)),
                count
            )
            field_move_wheel.select(field_move_wheel_index)
        return
    _close_field_move_wheel(true)

func _can_open_field_move_wheel() -> bool:
    return (
        GameOptions.enabled("radial") and started and not generating and not battle_active and not field_item_busy
        and not game_menu_open and not craft_menu_open
        and not quit_prompt_open and not touch_config.visible
        and not touch_controls.edit_mode
        and not _field_ui_blocks_gameplay(world.active_field_move == "BUILD") and world.gameplay_enabled
    )

func _field_ui_blocks_gameplay(ignore_build_hud: bool = false) -> bool:
    if is_instance_valid(coop_game) and coop_game.active and (coop_game.raids.active or coop_game.events.active or not coop_game.population_battles.claim.is_empty()):return true
    if is_instance_valid(coop_game) and coop_game.active and (coop_game.wild.encounter_pending or not coop_game.wild.encounter.is_empty()):return true
    if is_instance_valid(coop_game) and coop_game.active and not coop_game.session.trusted and started:return true
    if is_instance_valid(coop_game) and is_instance_valid(coop_game.interaction_ui) and coop_game.interaction_ui.visible:return true
    return ((is_instance_valid(pokedex_menu) and pokedex_menu.visible)
        or battle_active or battle_entry_pending or progression_active
        or mansion_switch_open or field_item_busy or game_menu_open
        or craft_menu_open or (build_menu_open and not ignore_build_hud) or quit_prompt_open
        or wild_pokemon_prompt_open or egg_pickup_open or storage_menu_open
        or trainer_tip_open or setup_load_open or pokemon_stats_open
        or touch_config.visible or touch_controls.edit_mode
        or (is_instance_valid(game_files_menu) and game_files_menu.visible)
        or (is_instance_valid(mod_menu_panel) and mod_menu_panel.visible))

func _field_move_wheel_stick() -> Vector2:
    for device in Input.get_connected_joypads():
        var stick := Vector2(
            Input.get_joy_axis(device, JOY_AXIS_LEFT_X),
            Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
        )
        if stick.length() >= 0.20:
            return stick
    return input_router.movement_vector()

func _open_field_move_wheel() -> void:
    field_quick_tap_at=-1
    field_quick_tap_move=-1
    if Input.is_action_pressed("field_move_wheel") and not Input.is_action_pressed("ball_mechanics") and _field_move_wheel_stick().length()<0.35 and world.active_field_move not in ["BUILD","SURF","RIDE","FLY"]:
        field_quick_tap_at=Time.get_ticks_msec()
        field_quick_tap_move=_quick_breakable_field_move()
    field_move_wheel_open = true
    field_move_wheel_index = -1
    build_wheel_mode = world.active_field_move == "BUILD"
    if build_wheel_mode:
        build_wheel_page = int(world.get_build_selection_index()) / BUILD_WHEEL_PAGE_SIZE
        _configure_build_wheel()
        build_panel.visible = false
    else:
        field_move_wheel.configure(_field_move_wheel_entries(), -1)
    field_move_wheel.visible = true
    message_panel.visible = false
    world.set_gameplay_enabled(false)

func _close_field_move_wheel(activate_selection: bool) -> void:
    if not field_move_wheel_open:
        return
    var selection := field_move_wheel_index
    if activate_selection and not build_wheel_mode and selection<0 and field_quick_tap_at>=0:
        var elapsed=Time.get_ticks_msec()-field_quick_tap_at
        if elapsed>=0 and elapsed<250 and field_quick_tap_move==_quick_breakable_field_move():
            selection=field_quick_tap_move
    field_quick_tap_at=-1
    field_move_wheel_open = false
    field_move_wheel.visible = false
    var can_resume := not _field_ui_blocks_gameplay(build_wheel_mode)
    if build_wheel_mode and build_menu_open: build_panel.visible = true
    world.set_gameplay_enabled(can_resume)
    if can_resume and activate_selection and selection >= 0:
        if build_wheel_mode:
            world.set_build_selection_index(build_wheel_page * BUILD_WHEEL_PAGE_SIZE + selection)
        else:
            _activate_field_move_wheel_selection(selection)

func _quick_breakable_field_move() -> int:
    var cell:Vector2i=world._player_cell()+world._facing_cell()
    if world.built_structures.has(cell):return -1
    var anchor:Vector2i=world._exact_resource_anchor(cell)
    var kind:String=world._exact_resource_kind(anchor)
    if kind.is_empty():
        anchor=world._resource_object_anchor(cell)
        kind=String(world.resource_objects.get(anchor,{}).get("type",""))
    var move_name=""
    if world._is_cuttable_grass_cell(cell) or kind in ["tree","bush"]:
        if _find_field_move_pokemon_index("CUT")>=0:move_name="CUT"
        elif kind=="tree" and _find_field_move_pokemon_index("HEADBUTT")>=0:move_name="HEADBUTT"
    elif kind=="rock" and _find_field_move_pokemon_index("SMASH")>=0:move_name="SMASH"
    if move_name.is_empty() or move_name==world.active_field_move:return -1
    return FIELD_MOVE_WHEEL_ORDER.find(move_name)

func _configure_build_wheel() -> void:
    var entries: Array[Dictionary] = []
    var start := build_wheel_page * BUILD_WHEEL_PAGE_SIZE
    for index in range(start, mini(start + BUILD_WHEEL_PAGE_SIZE, CraftingData.build_recipes().size())):
        var item := String(CraftingData.build_recipes()[index].name)
        entries.append({"move":CraftingData.build_display_name(item), "available":true,
            "texture":world._structure_display_texture(item), "build_item":true,
            "cost":CraftingData.build_recipes()[index].get("cost", {}).duplicate()})
    field_move_wheel_index = -1
    field_move_wheel.configure(entries, -1)
    field_move_wheel.page_label = "%d / %d  L / R" % [build_wheel_page + 1, ceili(float(CraftingData.build_recipes().size()) / BUILD_WHEEL_PAGE_SIZE)]
    field_move_wheel.queue_redraw()

func _field_move_wheel_entries() -> Array[Dictionary]:
    var entries: Array[Dictionary] = []
    for move_name in FIELD_MOVE_WHEEL_ORDER:
        var party_index := _find_field_move_pokemon_index(move_name)
        var species := String(FIELD_MOVE_REPRESENTATIVES[move_name])
        if party_index >= 0:
            species = String((caught_pokemon[party_index] as Dictionary).get(
                "species", species)).to_lower()
        if move_name == "PAINT":
            species = "smeargle"
        entries.append({
            "move": move_name,
            "species": species,
            "available": party_index >= 0,
            "party_index": party_index,
            "texture": _field_move_wheel_icon(species, party_index >= 0 and PokemonData.is_shiny(caught_pokemon[party_index]), String(caught_pokemon[party_index].get("form","")) if party_index>=0 else "")
        })
    return entries

func _find_field_move_pokemon_index(move_name: String) -> int:
    for index in range(caught_pokemon.size()):
        if typeof(caught_pokemon[index]) != TYPE_DICTIONARY:
            continue
        var pokemon := caught_pokemon[index] as Dictionary
        if bool(pokemon.get("is_egg", false)) or int(pokemon.get("hp", 1)) <= 0:
            continue
        if FieldMoveData.field_moves_for(String(pokemon.get("species", "")), String(pokemon.get("form", ""))).has(
                move_name):
            return index
    return -1

func _stop_fainted_active_field_move() -> void:
    if not started or battle_active:
        return
    var active_move := String(world.get("active_field_move"))
    if active_move.is_empty():
        return
    var active_pokemon := world.get("active_field_pokemon") as Dictionary
    var active_id := int(active_pokemon.get("ecology_id", -1))
    var active_species := String(active_pokemon.get("species", "")).to_lower()
    for raw_entry in caught_pokemon:
        if typeof(raw_entry) != TYPE_DICTIONARY:
            continue
        var entry := raw_entry as Dictionary
        var same_pokemon := (
            active_id >= 0 and int(entry.get("ecology_id", -2)) == active_id
        ) or (
            active_id < 0 and String(entry.get("species", "")).to_lower() ==
                active_species
        )
        if same_pokemon and int(entry.get("hp", 0)) > 0:
            return
    world.call("clear_active_field_move", true)

func _field_move_wheel_icon(species: String, shiny: bool = false, form: String = "") -> Texture2D:
    var key := "mega_gengar" if species=="gengar" and form=="mega" else species
    var menu := preload("res://scripts/divinakra_mega_art.gd").texture(key,"menu",shiny)
    if menu != null: return _source_texture_region(menu,Rect2(64,0,16,16))
    var texture := PokemonData.record_texture({"species":species,"shiny":shiny,"form":form}, "overworld")
    if texture == null:
        texture = PokemonData.texture(species, "front", shiny)
    if texture == null:
        return POKEMON_TEXTURES.get(species) as Texture2D
    if texture.has_meta("mega_gengar_walk"):
        var mega_frame := texture.get_width() / 6.0
        return _source_texture_region(texture,Rect2(mega_frame * 4.0,0,mega_frame,texture.get_height()))
    if texture.get_width() >= 16 and texture.get_height() >= 16:
        var frame := AtlasTexture.new()
        frame.atlas = texture
        frame.region = Rect2(0, 0, 16, 16)
        return frame
    return texture

func _activate_field_move_wheel_selection(selection: int) -> void:
    if selection < 0 or selection >= FIELD_MOVE_WHEEL_ORDER.size():
        return
    var move_name := String(FIELD_MOVE_WHEEL_ORDER[clampi(
        selection, 0, FIELD_MOVE_WHEEL_ORDER.size() - 1)])
    var party_index := _find_field_move_pokemon_index(move_name)
    if party_index < 0:
        if move_name != "CUT":
            _show_message("A POKEMON is required to use this FIELD MOVE.")
        return
    _ensure_party_ecology_id(party_index)
    var pokemon := caught_pokemon[party_index] as Dictionary
    if not bool(world.call("set_active_field_move", pokemon, move_name)):
        return
    world.call("present_field_move_pokemon")
    if move_name == "BUILD":
        _open_build_menu()
    elif move_name not in ["CUT", "DIG"]:
        _show_message("%s is using %s." % [
            PokemonData.battle_display_name(String(pokemon.get("species", "POKEMON"))), move_name])

func _start_battle_text(message: String) -> void:
    battle_text_full = message
    battle_status.text = message
    battle_status.visible_characters = 0
    battle_text_accumulator = 0.0
    battle_text_busy = not message.is_empty()
    if message.is_empty():
        battle_status.visible_characters = -1

func _type_battle_text(message: String) -> void:
    if overworld_evolution_running:
        progression_overlay.show()
        progression_level_dialogue.show()
        _set_evolution_message(message)
    _start_battle_text(message)
    if battle_text_busy:
        await battle_text_finished

func _battle_message_parts(message: String) -> Array[String]:
    var split_at := message.find("!")
    if split_at < 0:
        return [message.strip_edges(), ""]
    return [
        message.left(split_at + 1).strip_edges(),
        message.substr(split_at + 1).strip_edges()
    ]

func _finish_battle_text() -> void:
    if not battle_text_busy:
        return
    battle_status.text = battle_text_full
    battle_status.visible_characters = -1
    battle_text_busy = false
    battle_text_accumulator = 0.0
    battle_text_finished.emit()

func _create_evolution_greyscale_material() -> void:
    var shader := Shader.new()
    # This is the nonlinear 5-bit greyscale shader used by EvolutionAnim in
    # the source JAR, translated directly to Godot's canvas shader syntax.
    shader.code = (
        "shader_type canvas_item;\n" +
        "void fragment() {\n" +
        "  vec4 c = texture(TEXTURE, UV) * COLOR;\n" +
        "  float r = floor(c.r * 31.0);\n" +
        "  float g = floor(c.g * 31.0);\n" +
        "  float b = floor(c.b * 31.0);\n" +
        "  float sum = r + g + b;\n" +
        "  float grey = floor(sum * sum * sum / 25947.0) / 31.0;\n" +
        "  COLOR = vec4(vec3(grey), c.a);\n" +
        "}\n"
    )
    evolution_greyscale_material = ShaderMaterial.new()
    evolution_greyscale_material.shader = shader

func _handle_progression_input(event: InputEvent) -> void:
    if progression_mode == "HATCH_ANIMATION":
        if event.is_action_pressed("confirm") and not event.is_echo():
            hatch_skip_requested = true
        get_viewport().set_input_as_handled()
        return
    if progression_mode == "EVOLUTION":
        if not overworld_evolution_running and event.is_action_pressed("cancel"):
            evolution_cancel_requested = true
            get_viewport().set_input_as_handled()
        return
    if progression_mode in ["STATS", "HATCH_DONE"]:
        if progression_waiting_input and (event.is_action_pressed("confirm") or
                event.is_action_pressed("start")):
            progression_waiting_input = false
            progression_confirmed.emit()
            get_viewport().set_input_as_handled()
        return
    if progression_mode == "MOVE_SELECT":
        var moves: Array = progression_pokemon.get("moves", [])
        if moves.is_empty():
            return
        if event.is_action_pressed("move_up") or event.is_action_pressed("move_left"):
            progression_choice_index = wrapi(
                progression_choice_index - 1, 0, moves.size())
            _refresh_progression_move_menu()
        elif event.is_action_pressed("move_down") or event.is_action_pressed("move_right"):
            progression_choice_index = wrapi(
                progression_choice_index + 1, 0, moves.size())
            _refresh_progression_move_menu()
        elif event.is_action_pressed("confirm"):
            progression_mode = ""
            progression_choice_made.emit(progression_choice_index)
        elif event.is_action_pressed("cancel"):
            _show_progression_yes_no(
                "Give up on learning %s?" % progression_pending_move.replace("_", " "),
                "MOVE_GIVEUP")
        else:
            return
        get_viewport().set_input_as_handled()
        return
    if progression_mode in ["MOVE_GIVEUP", "YES_NO"]:
        if event.is_action_pressed("move_up") or event.is_action_pressed("move_down") or \
                event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
            progression_choice_index = 1 - progression_choice_index
            _refresh_progression_yes_no()
        elif event.is_action_pressed("confirm"):
            if progression_mode == "MOVE_GIVEUP":
                if progression_choice_index == 0:
                    progression_mode = ""
                    progression_choice_made.emit(-1)
                else:
                    _show_progression_move_menu(
                        progression_pokemon, progression_pending_move)
            else:
                progression_mode = ""
                progression_choice_made.emit(
                    1 if progression_choice_index == 0 else 0)
        elif event.is_action_pressed("cancel"):
            if progression_mode == "MOVE_GIVEUP":
                _show_progression_move_menu(
                    progression_pokemon, progression_pending_move)
            else:
                progression_mode = ""
                progression_choice_made.emit(0)
        else:
            return
        get_viewport().set_input_as_handled()

func _reset_progression_overlay() -> void:
    progression_level_message.add_theme_font_size_override("font_size", 10)
    progression_level_message.position = Vector2(12,10)
    progression_level_message.size = Vector2(282,32)
    for panel in [progression_move_frame, progression_type_frame, progression_choice_frame]:
        if panel != null:
            panel.hide()
    progression_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    progression_background.position = Vector2.ZERO
    progression_animation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    progression_animation.position = Vector2.ZERO
    progression_background.texture = null
    progression_animation.texture = null
    progression_sprite_top.texture = null
    progression_sprite_bottom.texture = null
    progression_sprite_top.material = null
    progression_sprite_bottom.material = null
    progression_sprite_top.visible = false
    progression_sprite_bottom.visible = false
    progression_title.visible = false
    progression_list.visible = false
    progression_values.visible = false
    progression_cursor.visible = false
    progression_detail.visible = false
    progression_hint.visible = false
    progression_level_dialogue.visible = false
    if progression_stats_frame != null:
        progression_stats_frame.visible = false

func _hide_progression_overlay() -> void:
    progression_mode = ""
    progression_waiting_input = false
    progression_overlay.visible = capture_experience_presenting
    _reset_progression_overlay()

func _source_texture_region(texture: Texture2D, region: Rect2) -> Texture2D:
    if texture == null:
        return null
    var atlas := AtlasTexture.new()
    atlas.atlas = texture
    atlas.region = region
    return atlas

func _source_animation_frame_texture(source_key: String,
        frame_index: int) -> Texture2D:
    var animations: Dictionary = battle_animation_manifest.get("animations", {})
    var animation: Dictionary = animations.get(source_key, {})
    if animation.is_empty():
        return null
    var raw_sheets = animation.get("sheets", [])
    var sheets: Array = raw_sheets if typeof(raw_sheets) == TYPE_ARRAY else []
    if sheets.is_empty():
        sheets.append({
            "path": String(animation.get("path", "")),
            "start_frame": 0,
            "frames": int(animation.get("frames", 0))
        })
    var sheet_entry: Dictionary = {}
    for raw_sheet in sheets:
        if typeof(raw_sheet) != TYPE_DICTIONARY:
            continue
        var candidate := raw_sheet as Dictionary
        var start := int(candidate.get("start_frame", 0))
        var length := int(candidate.get("frames", 0))
        if frame_index >= start and frame_index < start + length:
            sheet_entry = candidate
            break
    if sheet_entry.is_empty():
        return null
    var sheet_path := String(sheet_entry.get("path", ""))
    var sheet := battle_animation_cache.get(sheet_path) as Texture2D
    if sheet == null and ResourceLoader.exists(sheet_path):
        sheet = load(sheet_path) as Texture2D
        if sheet != null:
            battle_animation_cache[sheet_path] = sheet
    if sheet == null:
        return null
    var columns := maxi(1, int(animation.get("columns", 15)))
    var frame_width := int(animation.get("frame_width", 160))
    var frame_height := int(animation.get("frame_height", 144))
    var local_frame := frame_index - int(sheet_entry.get("start_frame", 0))
    return _source_texture_region(sheet, Rect2(
        float((local_frame % columns) * frame_width),
        float(int(local_frame / columns) * frame_height),
        float(frame_width), float(frame_height)))

func _source_animation_directive(source_key: String,
        frame_index: int) -> Dictionary:
    var animations: Dictionary = battle_animation_manifest.get("animations", {})
    var animation: Dictionary = animations.get(source_key, {})
    var directives: Dictionary = animation.get("directives", {})
    return (directives.get(str(frame_index + 1), {}) as Dictionary)

func _show_level_up_stats(pokemon: Dictionary) -> void:
    _reset_progression_overlay()
    progression_overlay.visible = true
    progression_background.texture = null
    var species := String(pokemon.get("species", "machop"))
    var stats_texture := PokemonData.record_texture(pokemon, "back")
    if stats_texture == null:
        stats_texture = PokemonData.record_texture(pokemon, "front")
    progression_sprite_top.texture = _battle_sprite_frame(stats_texture)
    # Stands on the text box (top edge at 123), as it does during the battle.
    progression_sprite_top.position = Vector2(14, 29)
    progression_sprite_top.size = Vector2(116, 94)
    progression_sprite_top.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    progression_sprite_top.visible = progression_sprite_top.texture != null
    var stats: Dictionary = pokemon.get("stats", {})
    for index in range(5):
        progression_stats_fields[index].text = str(int(stats.get(
            ["attack", "defense", "sp_attack", "sp_defense", "speed"][index], 0)))
    progression_stats_frame.visible = true
    progression_level_message.text = "%s grew to LV.%d!" % [
        PokemonState.display_name(pokemon).to_upper(),
        int(pokemon.get("level", 1))
    ]
    progression_level_dialogue.visible = true
    progression_mode = "STATS"
    progression_waiting_input = false
    await get_tree().create_timer(
        SOURCE_LEVEL_STATS_MIN_FRAMES * SOURCE_FRAME_TIME).timeout
    progression_waiting_input = true
    progression_hint.text = ""
    progression_hint.visible = false
    await progression_confirmed
    _hide_progression_overlay()

func _progression_panel(label: String, rect: Rect2) -> Panel:
    var panel := Panel.new()
    panel.name = label
    panel.position = rect.position
    panel.size = rect.size
    panel.z_index = 2
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel", _classic_dialogue_style())
    progression_overlay.add_child(panel)
    panel.hide()
    return panel

func _create_progression_menu_frames() -> void:
    progression_type_frame = _progression_panel("MoveTypeBorder", Rect2(142, 2, 176, 117))
    progression_move_frame = _progression_panel("MoveListBorder", Rect2(2, 2, 138, 117))
    progression_choice_frame = _progression_panel("MoveChoiceBorder", Rect2(234, 51, 84, 70))
    progression_type_label = _source_ui_label(progression_type_frame, "Type", Vector2(10, 10), Vector2(156, 95), 8)
    progression_type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    progression_pp_label = _source_ui_label(progression_type_frame, "PP", Vector2(12, 67), Vector2(94, 34), 10)
    for index in range(4):
        var row := _source_ui_label(progression_move_frame, "Move%d" % index,
            Vector2(24, 10 + index * 25), Vector2(104, 20), 10)
        row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        progression_move_rows.append(row)
    progression_menu_cursor = _source_ui_label(progression_move_frame, "Tick", Vector2(8, 10), Vector2(14, 20), 10, "▶", true)
    progression_menu_cursor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    progression_yes_no_cursor = _source_ui_label(progression_choice_frame, "Tick", Vector2(11, 8), Vector2(14, 20), 10, "▶", true)
    progression_yes_no_cursor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    for index in range(2):
        var row := _source_ui_label(progression_choice_frame, "Choice%d" % index,
            Vector2(28, 10 + index * 28), Vector2(46, 22), 10, "YES" if index == 0 else "NO")
        row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _show_progression_move_menu(pokemon: Dictionary, move_name: String) -> void:
    _reset_progression_overlay()
    progression_overlay.show()
    progression_pokemon = pokemon
    progression_pending_move = move_name.to_upper().replace(" ", "_")
    var moves: Array = pokemon.get("moves", [])
    progression_choice_index = clampi(progression_choice_index, 0, maxi(0, moves.size() - 1))
    progression_level_message.text = "Which move should be forgotten?"
    progression_level_dialogue.show()
    progression_move_frame.show()
    progression_type_frame.show()
    progression_mode = "MOVE_SELECT"
    _refresh_progression_move_menu()

func _refresh_progression_move_menu() -> void:
    var moves: Array = progression_pokemon.get("moves", [])
    for index in range(4):
        var row := progression_move_rows[index]
        row.text = String(moves[index]).replace("_", " ") if index < moves.size() else "-"
        var font_size := 10
        while font_size > 6 and row.get_theme_font("font").get_string_size(row.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > row.size.x:
            font_size -= 1
        row.add_theme_font_size_override("font_size", font_size)
    _align_menu_tick(progression_menu_cursor, progression_move_rows[progression_choice_index])
    if moves.is_empty():
        progression_type_label.text = "TYPE/\n---"
        progression_pp_label.text = "PP\n0/0"
        return
    var selected := String(moves[progression_choice_index])
    var move_data := PokemonData.move_info(selected)
    var maximum_pp := int(move_data.get("pp", 0))
    var current_pp := int((progression_pokemon.get("pp", {}) as Dictionary).get(selected, maximum_pp))
    var details = preload("res://scripts/move_details.gd")
    progression_pp_label.hide()
    progression_type_label.text = "%s\nPP %d / %d\n\n%s" % [details.stats_text(selected).replace("  PP %d" % maximum_pp,""),current_pp,maximum_pp,details.effect_text(selected)]
    progression_level_message.add_theme_font_size_override("font_size", 7)
    progression_level_message.position = Vector2(12,7)
    progression_level_message.size = Vector2(288,44)
    progression_level_message.text = "NEW: %s\n%s\n%s" % [progression_pending_move.replace("_"," "), details.stats_text(progression_pending_move).replace("\n","  "), details.effect_text(progression_pending_move)]

func _show_progression_yes_no(prompt: String, mode: String = "YES_NO") -> void:
    _reset_progression_overlay()
    progression_overlay.show()
    progression_level_message.text = prompt
    progression_level_dialogue.show()
    progression_choice_frame.show()
    progression_choice_index = 0
    progression_mode = mode
    _refresh_progression_yes_no()

func _refresh_progression_yes_no() -> void:
    _align_menu_tick(progression_yes_no_cursor, progression_choice_frame.get_node("Choice%d" % progression_choice_index))

func _ask_progression_yes_no(prompt: String) -> bool:
    _show_progression_yes_no(prompt)
    var result = await progression_choice_made
    return int(result) == 1

func _choose_move_to_forget(pokemon: Dictionary,
        move_name: String) -> int:
    progression_choice_index = 0
    while true:
        _show_progression_move_menu(pokemon, move_name)
        var choice = await progression_choice_made
        var selected_index := int(choice)
        if selected_index < 0:
            _hide_progression_overlay()
            return -1
        var moves: Array = pokemon.get("moves", [])
        if selected_index >= moves.size():
            continue
        var forgotten := String(moves[selected_index]).replace("_", " ")
        if await _ask_progression_yes_no("Replace %s?" % forgotten):
            _hide_progression_overlay()
            return selected_index
    return -1

func _learn_level_moves(pokemon: Dictionary, moves_to_learn: Array) -> void:
    var display_name := PokemonState.display_name(pokemon).to_upper()
    for raw_move in moves_to_learn:
        var move_name := String(raw_move).to_upper().replace(" ", "_")
        if (pokemon.get("moves", []) as Array).has(move_name):
            continue
        if (pokemon.get("moves", []) as Array).size() < 4:
            if BattleEngine.learn_move(pokemon, move_name):
                _play_source_battle_sound("fanfare1.ogg")
                await _type_battle_text("%s learned %s!" % [
                    display_name, move_name.replace("_", " ")])
            continue
        await _type_battle_text("%s is trying to learn %s." % [
            display_name, move_name.replace("_", " ")])
        await _type_battle_text("Which move should be forgotten?")
        var replace_index := await _choose_move_to_forget(pokemon, move_name)
        if replace_index < 0:
            await _type_battle_text("%s did not learn %s." % [
                display_name, move_name.replace("_", " ")])
            continue
        var old_move := String((pokemon.get("moves", []) as Array)[replace_index])
        await _type_battle_text("And one... two... three... POOF!")
        await _type_battle_text("%s forgot %s and..." % [
            display_name, old_move.replace("_", " ")])
        if BattleEngine.learn_move(pokemon, move_name, replace_index):
            _play_source_battle_sound("fanfare1.ogg")
            await _type_battle_text("%s learned %s!" % [
                display_name, move_name.replace("_", " ")])

func _experience_bar_index(species: String, level: int,
        experience: int) -> int:
    if level >= 100:
        return SOURCE_EXP_UNITS
    var floor_exp := BattleEngine.exp_for_level(species, level)
    var ceiling_exp := BattleEngine.exp_for_level(species, level + 1)
    return clampi(int(floor(float(SOURCE_EXP_UNITS) *
        float(experience - floor_exp) /
        maxf(1.0, float(ceiling_exp - floor_exp)))), 0, SOURCE_EXP_UNITS)

func _animate_experience_segment(pokemon: Dictionary, from_exp: int,
        to_exp: int) -> void:
    var species := String(pokemon.get("species", "machop"))
    var level := int(pokemon.get("level", 1))
    var start_index := _experience_bar_index(species, level, from_exp)
    var target_index := _experience_bar_index(species, level, to_exp)
    var segment_start := preload("res://scripts/game_clock.gd").ticks_usec()
    for bar_index in range(start_index + 1, target_index + 1):
        _set_player_exp_bar_ratio(
            float(bar_index) / float(SOURCE_EXP_UNITS))
        var deadline := segment_start + int((bar_index - start_index) * SOURCE_FRAME_TIME * 1000000.0)
        while preload("res://scripts/game_clock.gd").ticks_usec() < deadline:
            await get_tree().process_frame

func _set_player_exp_bar_ratio(ratio: float) -> void:
    var clamped := clampf(ratio, 0.0, 1.0)
    var legacy_width := roundf(96.0 * clamped)
    var source_width := roundf(66.0 * clamped)
    # Both bars share a fixed right edge like the source GSC HUD.
    player_exp_fill.position.x = 145.0 - legacy_width
    player_exp_fill.size.x = legacy_width
    source_player_exp_fill.position.x = 184.0 - source_width
    source_player_exp_fill.size.x = source_width
    player_exp_fill.color = Color8(47, 152, 233)
    source_player_exp_fill.color = Color8(32, 136, 248)

func _world_source_time_of_day() -> String:
    if world.has_method("source_time_of_day"):
        return String(world.call("source_time_of_day"))
    return "day"

func _run_experience_progression(pokemon: Dictionary, amount: int,
        party_index: int, defer_evolution: bool = false) -> void:
    progression_active = true
    progression_mode = ""
    _hide_progression_overlay()
    var original_hud_pokemon := battle_player
    var showing_other_pokemon := not is_same(pokemon, battle_player)
    if showing_other_pokemon:
        battle_player = pokemon
        _update_battle_hud()

    var current_exp := int(pokemon.get("exp", BattleEngine.exp_for_level(
        String(pokemon.get("species", "machop")), int(pokemon.get("level", 1)))))
    var target_exp := current_exp + maxi(0, amount)
    var gained_level := false
    if int(pokemon.get("level", 1)) < 100 and target_exp > current_exp:
        _play_source_battle_sound("xp-gain1.ogg")
        await get_tree().create_timer(9.0 * SOURCE_FRAME_TIME).timeout

    while int(pokemon.get("level", 1)) < 100:
        var next_level_exp := BattleEngine.exp_for_level(
            String(pokemon.get("species", "machop")),
            int(pokemon.get("level", 1)) + 1)
        if target_exp < next_level_exp:
            break
        await _animate_experience_segment(pokemon, current_exp, next_level_exp)
        pokemon["exp"] = next_level_exp
        battle_audio.stop()
        _play_level_up_sound()
        _set_player_exp_bar_ratio(1.0)
        # The source holds a completely filled bar before it rolls into the
        # next level rather than clearing it on the same frame.
        await get_tree().create_timer(9.0 * SOURCE_FRAME_TIME).timeout
        var level_result := BattleEngine.gain_level(pokemon)
        gained_level = true
        current_exp = next_level_exp
        if party_index >= 0 and party_index < caught_pokemon.size():
            caught_pokemon[party_index] = pokemon
        _update_battle_hud()
        _play_source_battle_sound("fanfare1.ogg")
        await _type_battle_text("%s grew to level %d!" % [
            PokemonState.display_name(pokemon).to_upper(), int(pokemon.level)])
        await _learn_level_moves(pokemon, level_result.get("moves", []))
        if int(pokemon.get("level", 1)) < 100 and target_exp >= \
                BattleEngine.exp_for_level(String(pokemon.species),
                    int(pokemon.level) + 1):
            _play_source_battle_sound("xp-gain1.ogg")

    if int(pokemon.get("level", 1)) < 100 and target_exp > current_exp:
        await _animate_experience_segment(pokemon, current_exp, target_exp)
    pokemon["exp"] = target_exp
    battle_audio.stop()
    if party_index >= 0 and party_index < caught_pokemon.size():
        caught_pokemon[party_index] = pokemon
    _update_battle_hud()

    if gained_level:
        await _show_level_up_stats(pokemon)
        if not defer_evolution:
            await _check_reward_evolution(pokemon, party_index)

    if showing_other_pokemon:
        battle_player = original_hud_pokemon
        _update_battle_hud()
    _hide_progression_overlay()
    progression_pokemon = {}
    progression_pending_move = ""
    progression_active = false

func _set_progression_sprite_half(node: TextureRect, texture: Texture2D,
        top_half: bool, greyscale: bool,
        source_baseline_y: float = 72.0, bottom_height: int = -1,
        horizontal_scale: float = 2.0, horizontal_offset: float = 0.0) -> void:
    if texture == null:
        node.texture = null
        node.visible = false
        return
    var width := texture.get_width()
    var height := texture.get_height()
    var split := height - bottom_height if bottom_height >= 0 else int(height / 2.0)
    var region_y := 0 if top_half else split
    var region_height := split if top_half else height - split
    node.texture = _source_texture_region(texture,
        Rect2(0, region_y, width, region_height))
    var source_left := 84.0 - float(width) / 2.0
    var source_top := 144.0 - source_baseline_y - float(height)
    node.position = Vector2(
        horizontal_offset + source_left * horizontal_scale,
        (source_top + float(region_y)) * 1.25)
    node.size = Vector2(float(width) * horizontal_scale, float(region_height) * 1.25)
    node.material = evolution_greyscale_material if greyscale else null
    node.visible = true

func _set_evolution_sprite_halves(old_texture: Texture2D,
        new_texture: Texture2D, directive: Dictionary,
        sprites_visible: bool) -> void:
    if not sprites_visible:
        progression_sprite_top.visible = false
        progression_sprite_bottom.visible = false
        return
    var greyscale := bool(directive.get("sprite_greyscale", false))
    var top_texture := new_texture if bool(directive.get(
        "evo_top_sprite_changed", false)) else old_texture
    var bottom_texture := new_texture if bool(directive.get(
        "evo_bottom_sprite_changed", false)) else old_texture
    _set_progression_sprite_half(
        progression_sprite_top, top_texture, true, greyscale, 72.0,
        int(old_texture.get_height() / 2.0), 1.25, 60.0)
    _set_progression_sprite_half(
        progression_sprite_bottom, bottom_texture, false, greyscale, 72.0,
        int(old_texture.get_height() / 2.0), 1.25, 60.0)

func _set_progression_full_sprite(texture: Texture2D,
        source_baseline_y: float) -> void:
    if texture == null:
        progression_sprite_top.visible = false
        progression_sprite_bottom.visible = false
        return
    progression_sprite_bottom.visible = false
    progression_sprite_top.texture = texture
    progression_sprite_top.material = null
    progression_sprite_top.position = Vector2(
        (84.0 - float(texture.get_width()) / 2.0) * 2.0,
        (144.0 - source_baseline_y - float(texture.get_height())) * 1.25)
    progression_sprite_top.size = Vector2(
        float(texture.get_width()) * 2.0,
        float(texture.get_height()) * 1.25)
    progression_sprite_top.visible = true

func _set_hatch_progression_canvas() -> void:
    # The source hatch canvas is 160x144. Fit it to the 320x180 viewport with
    # one uniform scale (1.25x) so the egg/Pokemon are never horizontally
    # stretched; the remaining 60 px on each side are intentional pillarbox.
    for node in [progression_background, progression_animation]:
        node.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
        node.position = Vector2(60.0, 0.0)
        node.size = Vector2(200.0, 180.0)

func _set_hatch_sprite_half(node: TextureRect, texture: Texture2D,
        top_half: bool, source_baseline_y: float = 64.0) -> void:
    if texture == null:
        node.texture = null
        node.visible = false
        return
    var width := texture.get_width()
    var height := texture.get_height()
    var split := int(height / 2.0)
    var region_y := 0 if top_half else split
    var region_height := split if top_half else height - split
    node.texture = _source_texture_region(texture,
        Rect2(0, region_y, width, region_height))
    var scale := 1.25
    var source_left := 84.0 - float(width) / 2.0
    var source_top := 144.0 - source_baseline_y - float(height)
    node.position = Vector2(
        60.0 + source_left * scale,
        (source_top + float(region_y)) * scale)
    node.size = Vector2(float(width) * scale, float(region_height) * scale)
    node.material = null
    node.visible = true

func _set_hatch_full_sprite(texture: Texture2D,
        source_baseline_y: float = 64.0) -> void:
    if texture == null:
        progression_sprite_top.visible = false
        progression_sprite_bottom.visible = false
        return
    var scale := 1.25
    progression_sprite_bottom.visible = false
    progression_sprite_top.texture = texture
    progression_sprite_top.material = null
    progression_sprite_top.position = Vector2(
        60.0 + (84.0 - float(texture.get_width()) / 2.0) * scale,
        (144.0 - source_baseline_y - float(texture.get_height())) * scale)
    progression_sprite_top.size = Vector2(
        float(texture.get_width()) * scale,
        float(texture.get_height()) * scale)
    progression_sprite_top.visible = true

func _set_hatch_sprite_halves(texture: Texture2D,
        show_bottom: bool, show_top: bool) -> void:
    if show_top:
        _set_hatch_sprite_half(
            progression_sprite_top, texture, true, 64.0)
    else:
        progression_sprite_top.visible = false
    if show_bottom:
        _set_hatch_sprite_half(
            progression_sprite_bottom, texture, false, 64.0)
    else:
        progression_sprite_bottom.visible = false

func _play_battle_animation_sound(source_key: String) -> void:
    var audio_entries: Dictionary = battle_animation_manifest.get("audio", {})
    var audio_path := String(audio_entries.get(source_key, ""))
    if not audio_path.is_empty() and ResourceLoader.exists(audio_path):
        battle_audio.stream = load(audio_path) as AudioStream
        AudioBalance.apply(battle_audio)
        battle_audio.play()

func _play_progression_cry(pokemon: Dictionary) -> void:
    var cry_path := PokemonData.cry_path(String(pokemon.get("species", "")))
    if cry_path.is_empty() or not ResourceLoader.exists(cry_path):
        return
    var cry_player := AudioStreamPlayer.new()
    cry_player.stream = load(cry_path) as AudioStream
    cry_player.finished.connect(func() -> void: cry_player.queue_free())
    add_child(cry_player)
    AudioBalance.apply(cry_player)
    cry_player.play()

func _run_egg_hatch_sequence(party_index: int, hatched: Dictionary) -> void:
    progression_active = true
    progression_mode = ""
    field_item_busy = true
    world.set_gameplay_enabled(false)
    caught_pokemon[party_index] = hatched
    pokedex_progress.mark(hatched, true)
    var species := String(hatched.get("species", "pidgey")).to_lower()
    if not caught_species.has(species):
        caught_species.append(species)

    # PlayerStanding waits 61 + 3 source frames before its random hatch cue.
    await get_tree().create_timer(61.0 * SOURCE_FRAME_TIME).timeout
    await get_tree().create_timer(3.0 * SOURCE_FRAME_TIME).timeout
    message_timer = 0.0
    message_label.text = ["Huh?", "Oh?"][battle_rng.randi_range(0, 1)]
    message_panel.visible = true
    await get_tree().create_timer(51.0 * SOURCE_FRAME_TIME).timeout
    message_panel.visible = false

    _reset_progression_overlay()
    progression_overlay.visible = true
    _set_hatch_progression_canvas()
    progression_background.texture = _source_texture_region(
        SOURCE_HATCH_BACKGROUND, Rect2(0, 0, 160, 144))
    progression_mode = "HATCH_ANIMATION"
    var skip_hint := _source_ui_label(progression_overlay, "HatchSkipHint", Vector2(190, 167), Vector2(124, 11), 7, "Press A to skip")
    skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    skip_hint.z_index = 10
    hatch_skip_requested = false
    var previous_pitch := battle_audio.pitch_scale
    battle_audio.pitch_scale = HATCH_PLAYBACK_SPEED
    _play_battle_animation_sound("egg_hatch_gsc")
    var front_sheet := PokemonData.record_texture(hatched, "front")
    var front_frame := _battle_sprite_frame(front_sheet)
    var show_bottom := false
    var show_top := false
    # One elapsed-time clock advances both visuals and pitched source audio.
    # Per-frame timers accumulated extra display frames on slower devices.
    var hatch_start := preload("res://scripts/game_clock.gd").ticks_usec()
    var last_frame := -1
    while not hatch_skip_requested:
        var frame_index := int(float(preload("res://scripts/game_clock.gd").ticks_usec() - hatch_start) / 1000000.0 * HATCH_PLAYBACK_SPEED / SOURCE_FRAME_TIME)
        if frame_index >= SOURCE_HATCH_COMPLETE_FRAME:
            break
        progression_animation.texture = _source_animation_frame_texture(
            "egg_hatch_gsc", frame_index)
        for directive_frame in range(last_frame + 1, frame_index + 1):
            var directive := _source_animation_directive("egg_hatch_gsc", directive_frame)
            show_bottom = show_bottom or bool(directive.get("draw_hatch_bottom_sprite", false))
            show_top = show_top or bool(directive.get("draw_hatch_top_sprite", false))
        last_frame = frame_index
        _set_hatch_sprite_halves(front_frame, show_bottom, show_top)
        await get_tree().process_frame

    battle_audio.stop()
    battle_audio.pitch_scale = previous_pitch
    skip_hint.queue_free()
    progression_mode = "HATCH_REVEAL"
    progression_animation.texture = null
    var intro_frame_count := 1
    if front_sheet != null and front_sheet.get_width() > 0:
        intro_frame_count = maxi(1, roundi(
            float(front_sheet.get_height()) / float(front_sheet.get_width())))
    var cry_started := false
    var reveal_start := preload("res://scripts/game_clock.gd").ticks_usec()
    for intro_index in range(intro_frame_count):
        var sprite_frame := front_frame
        if front_sheet != null and front_sheet.get_height() > front_sheet.get_width():
            var frame_height := mini(front_sheet.get_height(), front_sheet.get_width())
            sprite_frame = _source_texture_region(front_sheet, Rect2(
                0, intro_index * frame_height,
                front_sheet.get_width(), frame_height))
        _set_hatch_full_sprite(sprite_frame, 64.0)
        var deadline := reveal_start + int((intro_index + 1) * SOURCE_FRAME_TIME * 1000000.0)
        while preload("res://scripts/game_clock.gd").ticks_usec() < deadline:
            await get_tree().process_frame
        if intro_index == 3:
            _play_progression_cry(hatched)
            cry_started = true
    if not cry_started:
        _play_progression_cry(hatched)
    await get_tree().create_timer(4.0 * SOURCE_FRAME_TIME).timeout

    _hide_progression_overlay()
    _play_source_battle_sound("fanfare2.ogg")
    message_timer = 0.0
    message_label.text = "%s came out of its EGG!" % \
        PokemonState.display_name(hatched).to_upper()
    message_panel.visible = true
    progression_mode = "HATCH_DONE"
    progression_waiting_input = true
    await progression_confirmed
    await get_tree().create_timer(13.0 * SOURCE_FRAME_TIME).timeout
    battle_audio.stop()
    message_panel.visible = false
    progression_mode = ""
    progression_waiting_input = false
    progression_active = false
    field_item_busy = false
    world.set_gameplay_enabled(true)

func _evolution_sprite_texture(species: String, shiny: bool) -> Texture2D:
    return PokemonData.texture(species, "front", shiny)

func _set_evolution_message(message: String) -> void:
    var font := progression_level_message.get_theme_font("font")
    var result := message
    var chosen_size := 10
    for size in range(10, 4, -1):
        var lines: Array[String] = [""]
        for word in message.split(" "):
            var candidate := word if lines[-1].is_empty() else lines[-1] + " " + word
            if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > 282 and not lines[-1].is_empty():
                lines.append(word)
            else:
                lines[-1] = candidate
        if lines.size() <= 2:
            result = "\n".join(lines)
            chosen_size = size
            break
    progression_level_message.add_theme_font_size_override("font_size", chosen_size)
    progression_level_message.text = result

func _run_evolution_sequence(pokemon: Dictionary, new_species: String,
        party_index: int) -> bool:
    new_species = BattleEngine.resolved_evolution_species(pokemon, new_species)
    var old_display_name := PokemonState.display_name(pokemon).to_upper()
    var old_texture := _battle_sprite_frame(
        _evolution_sprite_texture(String(pokemon.get("species", "")), PokemonData.is_shiny(pokemon)))
    var new_texture := _battle_sprite_frame(
        _evolution_sprite_texture(new_species, PokemonData.is_shiny(pokemon)))
    await _type_battle_text("What? %s is evolving!" % old_display_name)
    await get_tree().create_timer(51.0 * SOURCE_FRAME_TIME).timeout

    _reset_progression_overlay()
    progression_overlay.visible = true
    # Keep the source animation in its native proportions above the approved
    # dialogue panel; its baked-in vanilla border must not replace our UI.
    progression_background.texture = null
    progression_animation.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    progression_animation.position = Vector2(60.0, 0.0)
    progression_animation.size = Vector2(200.0, 120.0)
    progression_level_dialogue.visible = true
    _set_evolution_message("What? %s is evolving!" % old_display_name)
    progression_mode = "EVOLUTION"
    evolution_cancel_requested = false
    var evolution_music_states: Array[bool] = world.environment_system.pause_music_for_evolution()
    _play_source_battle_sound("evolution1.ogg")
    var animations: Dictionary = battle_animation_manifest.get("animations", {})
    var animation: Dictionary = animations.get("evolve_gsc", {})
    var frame_count := int(animation.get("frames", 502))
    var fanfare_played := false
    var evolution_started_usec := preload("res://scripts/game_clock.gd").ticks_usec()
    for frame_index in range(frame_count):
        if frame_index >= SOURCE_EVOLUTION_CANCEL_END_FRAME:
            progression_mode = "EVOLUTION_FINISHING"
        progression_animation.texture = _source_texture_region(
            _source_animation_frame_texture("evolve_gsc", frame_index),
            Rect2(0, 0, 160, 96))
        var directive := _source_animation_directive("evolve_gsc", frame_index)
        _set_evolution_sprite_halves(
            old_texture, new_texture, directive, frame_index >= 33)
        if bool(directive.get("play_evo_fanfare", false)) and not fanfare_played:
            fanfare_played = true
            _play_source_battle_sound("evolve_fanfare1.ogg")
        # Absolute deadlines preserve the source's 60 Hz timeline. Creating a
        # fresh one-frame timer per frame accumulated an extra render-frame wait.
        var deadline := evolution_started_usec + int(
            float(frame_index + 1) * SOURCE_FRAME_TIME * 1000000.0)
        while preload("res://scripts/game_clock.gd").ticks_usec() < deadline:
            await get_tree().process_frame
        if evolution_cancel_requested:
            break
    battle_audio.stop()
    world.environment_system.resume_music_after_evolution(evolution_music_states)
    progression_mode = "EVOLUTION_DONE"
    progression_animation.texture = null

    if evolution_cancel_requested:
        _set_evolution_sprite_halves(old_texture, old_texture, {}, true)
        await get_tree().create_timer(30.0 * SOURCE_FRAME_TIME).timeout
        _set_evolution_message("Huh? %s stopped evolving!" % old_display_name)
        await _type_battle_text("Huh? %s stopped evolving!" % old_display_name)
        _hide_progression_overlay()
        return false

    if not BattleEngine.apply_evolution(pokemon, new_species):
        _hide_progression_overlay()
        return false
    pokedex_progress.mark(pokemon, true)
    _set_evolution_sprite_halves(new_texture, new_texture, {}, true)
    if party_index >= 0 and party_index < caught_pokemon.size():
        caught_pokemon[party_index] = pokemon
    _refresh_battle_sprites()
    _update_battle_hud()
    _play_pokemon_cry(pokemon)
    await get_tree().create_timer(30.0 * SOURCE_FRAME_TIME).timeout
    _play_source_battle_sound("fanfare2.ogg")
    _set_evolution_message("Congratulations! Your %s evolved into %s!" % [
        old_display_name, new_species.to_upper().replace("_", " ")])
    await _type_battle_text("Congratulations! Your %s evolved into %s!" % [
        old_display_name, new_species.to_upper().replace("_", " ")])
    _hide_progression_overlay()
    await _learn_level_moves(pokemon, BattleEngine.moves_learned_at_level(
        new_species, int(pokemon.get("level", 1))))
    return true

func _notification(what: int) -> void:
    if not startup_complete: return
    if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
        start_menu_ticket += 1
        start_menu_pending = false
        start_menu_held = false
        # Releases can be delivered to the other window while unfocused.
        # Clear virtual controls as well as physical actions; preserve UI locks.
        for action in InputMap.get_actions():
            Input.action_release(action)
        if is_node_ready():
            touch_controls._release_all()
        return
    if what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
        if is_node_ready() and _is_android_touch_runtime():
            touch_controls.refresh_system_theme()
            if touch_config.visible:
                _apply_touch_config_theme()
        return

    if what != NOTIFICATION_WM_GO_BACK_REQUEST:
        return

    # Android system Back requests quit; controller Select has its own map action.
    if not _is_android_touch_runtime():
        if started and not quit_prompt_open:
            _open_quit_prompt()
        return
    _handle_android_back_request()

func _handle_android_back_request() -> void:
    if not _is_android_touch_runtime() or progression_active:
        return
    if is_instance_valid(waypoint_ui):
        if waypoint_ui.naming:
            waypoint_ui.cancel_name()
            last_android_back_msec = Time.get_ticks_msec()
            return
        if Time.get_ticks_msec() - waypoint_ui.closed_msec < 350:
            return
    var now := Time.get_ticks_msec()
    # Android can deliver one press as both a key event and a window Back
    # notification. Handle that pair once so the panel cannot open then close.
    if now - last_android_back_msec < 250:
        return
    last_android_back_msec = now
    if is_instance_valid(game_files_menu) and game_files_menu.visible:
        game_files_menu.close()
    elif is_instance_valid(mod_menu_panel) and mod_menu_panel.visible:
        mod_menu_panel.call("_close")
    elif touch_controls.edit_mode:
        touch_controls.end_edit()
        _open_touch_config()
    elif touch_config.visible:
        _close_touch_config()
    else:
        if is_instance_valid(pokedex_menu) and pokedex_menu.visible:
            pokedex_menu.close()
        _open_quit_prompt()

func _poll_android_back_bridge() -> void:
    if not android_back_bridge_checked:
        android_back_bridge_checked = true
        if OS.get_name() == "Android" and Engine.has_singleton("JavaClassWrapper"):
            var wrapper = Engine.get_singleton("JavaClassWrapper")
            android_back_bridge = wrapper.wrap("com.godot.game.PokeWildsBack")
    if android_back_bridge == null: return
    var action: int = int(android_back_bridge.consumeEvent())
    if action == 1:
        _handle_android_back_request()
    elif action == 2:
        _handle_android_controls_gesture()

func _handle_android_controls_gesture() -> void:
    if progression_active or quit_prompt_open: return
    if is_instance_valid(pokedex_menu) and pokedex_menu.visible: pokedex_menu.close()
    if touch_controls.edit_mode:
        touch_controls.end_edit()
        _open_touch_config()
    elif touch_config.visible:
        _close_touch_config()
    else:
        _open_touch_config()

func _input(event: InputEvent) -> void:
    if startup_complete and _menu_stick_event_is_blocked(event):
        get_viewport().set_input_as_handled()
        return
    if startup_complete and is_instance_valid(coop_game) and coop_game.handle_input(event):
        get_viewport().set_input_as_handled()
        return
    if startup_complete and is_instance_valid(coop_menu) and coop_menu.visible:
        coop_menu.handle(event)
        if not event is InputEventMouse and not event is InputEventScreenTouch and not event is InputEventScreenDrag and not coop_menu.accepts_text_key(event):
            get_viewport().set_input_as_handled()
        return
    if is_instance_valid(ball_mechanics) and is_instance_valid(ball_mechanics.capture_screen) and not capture_experience_presenting:
        get_viewport().set_input_as_handled()
        return
    if not startup_complete: return
    if is_instance_valid(waypoint_ui) and waypoint_ui.naming:
        waypoint_ui.handle_input(event)
        return # Dispatch before focused controls consume controller buttons.
    if game_menu_open and game_menu_detail_open and game_menu_map_screen.visible:
        _handle_game_menu_input(event)
        get_viewport().set_input_as_handled()
        return
    # Depending on the Android device/launcher, the hardware Back control can
    # arrive as KEY_BACK instead of a window Back notification.
    if event is InputEventKey and event.pressed and not event.echo and \
            _is_android_touch_runtime() and (event.keycode == KEY_BACK or \
                event.physical_keycode == KEY_BACK):
        _handle_android_back_request()
        get_viewport().set_input_as_handled()
        return
    if is_instance_valid(safari_ui) and battle_active and not quit_prompt_open and not touch_config.visible:
        safari_ui.handle(event)
        get_viewport().set_input_as_handled()
        return
    if is_instance_valid(bag_action_ui) and not quit_prompt_open and not touch_config.visible:
        bag_action_ui.handle(event)
        get_viewport().set_input_as_handled()
        return
    if is_instance_valid(pokedex_menu) and pokedex_menu.visible and not quit_prompt_open and not touch_config.visible:
        pokedex_menu.handle(event)
        get_viewport().set_input_as_handled()
        return
    if is_instance_valid(game_files_menu) and game_files_menu.visible:
        game_files_menu.handle(event)
        if not event is InputEventMouse and not event is InputEventScreenTouch and not event is InputEventScreenDrag:
            get_viewport().set_input_as_handled()
        return
    if is_instance_valid(mod_menu_panel) and mod_menu_panel.visible:
        mod_menu_panel.handle(event)
        if not event is InputEventMouse and not event is InputEventScreenTouch and not event is InputEventScreenDrag:
            get_viewport().set_input_as_handled()
        return


    if touch_config.visible:
        _handle_swipe_menu(event)
        if not event is InputEventMouse and not event is InputEventScreenTouch and not event is InputEventScreenDrag:
            get_viewport().set_input_as_handled()
        return
    if is_instance_valid(options_menu) and options_menu.visible:
        if is_instance_valid(options_menu.internet_setup) and options_menu.internet_setup.accepts_text_key(event):return
        options_menu.handle(event)
        if is_instance_valid(options_menu.internet_setup) and (event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag):return
        get_viewport().set_input_as_handled()
        return
    if field_move_wheel_open:
        if is_instance_valid(ball_mechanics) and ball_mechanics.handle(event):
            get_viewport().set_input_as_handled()
            return
        # L2 release and stick direction are polled in _process so the wheel
        # remains modal without stealing its selection axis from the player.
        if build_wheel_mode and (event.is_action_pressed("shoulder_left") or event.is_action_pressed("shoulder_right")):
            var pages := ceili(float(CraftingData.build_recipes().size()) / BUILD_WHEEL_PAGE_SIZE)
            build_wheel_page = posmod(build_wheel_page + (1 if event.is_action_pressed("shoulder_right") else -1), pages)
            _configure_build_wheel()
        elif event.is_action_pressed("cancel"):
            _close_field_move_wheel(false)
            field_wheel_wait_for_release = true
            if build_menu_open:
                _close_build_menu()
            elif not world.active_field_move.is_empty():
                world.clear_active_field_move()
        get_viewport().set_input_as_handled()
        return


    if build_menu_open and not field_move_wheel_open and not battle_active and not battle_entry_pending and not quit_prompt_open and event.is_action_pressed("cancel"):
        _close_build_menu()
        get_viewport().set_input_as_handled()
        return
    if started and event.is_action_pressed("cancel") and not world.active_field_move.is_empty() and not _field_ui_blocks_gameplay() and not _sleeping_bag_active() and not world.house_transition_active and not is_instance_valid(world.stool_seated_sprite):
        world.clear_active_field_move()
        get_viewport().set_input_as_handled()
        return
    if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START and not event.pressed:
        start_menu_held = false
    # Start/Select must never activate a focused control behind the quit modal.
    if quit_prompt_open and (event.is_action("start") or event.is_action("quit_menu")):
        get_viewport().set_input_as_handled()
        return
    # Capture printable WORLD NAME keys before Control focus can consume them.
    # Navigation/confirm/cancel still fall through to _unhandled_input.
    if text_entry_target != "" and event is InputEventKey:
        var text_key := event as InputEventKey
        if text_key.pressed and not text_key.echo:
            if text_key.keycode == KEY_BACKSPACE:
                if not text_entry_buffer.is_empty():
                    text_entry_buffer = text_entry_buffer.left(text_entry_buffer.length() - 1)
                    _refresh_text_entry_display()
                get_viewport().set_input_as_handled()
                return
            if text_key.unicode >= 32 and text_key.unicode != 127:
                if text_entry_buffer.length() < 24:
                    text_entry_buffer += String.chr(text_key.unicode)
                    _refresh_text_entry_display()
                get_viewport().set_input_as_handled()
                return
    if setup_load_open:
        _handle_setup_load_input(event)
        return

func _unhandled_input(event: InputEvent) -> void:
    if not startup_complete: return
    if is_instance_valid(coop_menu) and coop_menu.visible:return
    if is_instance_valid(waypoint_ui) and waypoint_ui.naming:
        return
    if is_instance_valid(world.stool_seated_sprite):
        if event.is_action_pressed("cancel"):
            world.end_stool_sitting()
        else:
            for action in ["move_up", "move_down", "move_left", "move_right"]:
                if event.is_action_pressed(action):
                    world.turn_seated_player(action)
                    break
        get_viewport().set_input_as_handled()
        return
    if world.house_transition_active:
        get_viewport().set_input_as_handled()
        return
    if mansion_switch_open:
        _handle_mansion_switch_input(event)
        return
    if wild_pokemon_prompt_open:
        _handle_wild_pokemon_prompt_input(event)
        return
    if egg_pickup_open:
        _handle_egg_pickup_input(event)
        return
    if storage_menu_open:
        _handle_storage_menu_input(event)
        return
    if trainer_tip_open:
        if event.is_action_pressed("confirm") or event.is_action_pressed("start"):
            _advance_trainer_tip()
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("cancel"):
            _close_trainer_tip()
            get_viewport().set_input_as_handled()
        return

    if setup_load_open:
        _handle_setup_load_input(event)
        return

    if pokemon_stats_open:
        _handle_pokemon_stats_input(event)
        return

    if event.is_action_pressed("touch_config"):
        if not _is_android_touch_runtime():
            return
        if touch_controls.edit_mode:
            touch_controls.end_edit()
            _open_touch_config()
        elif touch_config.visible:
            _close_touch_config()
        else:
            _open_touch_config()
        get_viewport().set_input_as_handled()
        return

    if touch_config.visible:
        if event.is_action_pressed("cancel") or event.is_action_pressed("start"):
            _close_touch_config()
            get_viewport().set_input_as_handled()
        return

    if touch_controls.edit_mode:
        if event.is_action_pressed("quit_menu") or event.is_action_pressed("cancel"):
            touch_controls.end_edit()
            _open_touch_config()
            get_viewport().set_input_as_handled()
        return

    if progression_active:
        _handle_progression_input(event)
        return


    if quit_prompt_open:
        _handle_quit_prompt_input(event)
        return

    if battle_entry_pending:
        return

    if event.is_action_pressed("quit_menu"):
        _open_quit_prompt()
        get_viewport().set_input_as_handled()
        return

    if battle_active:
        if battle_text_busy and (event.is_action_pressed("confirm") or
                event.is_action_pressed("start")):
            _finish_battle_text()
            get_viewport().set_input_as_handled()
            return
        if battle_text_busy:
            return
        if battle_item_pocket_open:
            _handle_battle_item_pocket_input(event)
            return
        if not battle_submenu_mode.is_empty():
            _handle_battle_submenu_input(event)
            return
        if battle_ui_mode == "INTRO":
            if event.is_action_pressed("confirm") or event.is_action_pressed("start"):
                _advance_battle_intro()
                get_viewport().set_input_as_handled()
            return
        if battle_ui_mode == "MOVE":
            _handle_battle_move_input(event)
            return
        if battle_ui_mode != "COMMAND":
            return
        if event.is_action_pressed("move_up"):
            _move_battle_command(0, -1)
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("move_down"):
            _move_battle_command(0, 1)
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("move_left"):
            _move_battle_command(-1, 0)
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("move_right"):
            _move_battle_command(1, 0)
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("confirm"):
            _activate_battle_command()
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("pokedex"):
            _repeat_last_battle_ball()
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("battle_catch"):
            _battle_catch()
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("shoulder_left"):
            _cycle_battle_move(-1)
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("shoulder_right"):
            _cycle_battle_move(1)
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("start"):
            _open_battle_party_menu("PARTY")
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("cancel"):
            _battle_run()
            get_viewport().set_input_as_handled()
        return

    if generating:
        return

    if build_menu_open:
        _handle_build_menu_input(event)
        return

    if craft_menu_open:
        _handle_crafting_input(event)
        return

    if started:
        if event.is_action_pressed("map_open"):
            if game_menu_open and game_menu_detail_open and game_menu_map_screen.visible and not teleport_map_mode:
                _close_game_menu()
            elif not _field_ui_blocks_gameplay() and not field_move_wheel_open and not _sleeping_bag_active():
                _open_game_menu()
                _show_map_menu()
            get_viewport().set_input_as_handled()
            return
        if game_menu_open:
            _handle_game_menu_input(event)
            return

        if _sleeping_bag_active():
            if event.is_action_pressed("cancel"):
                _end_sleeping_bag_rest()
                get_viewport().set_input_as_handled()
            elif event.is_action_pressed("start"):
                _queue_start_menu(event)
                get_viewport().set_input_as_handled()
            # Confirm and movement do not dismiss the sleeping bag.
            return

        if event.is_action_pressed("pokedex"):
            if not _field_ui_blocks_gameplay() and not field_move_wheel_open:
                pokedex_menu.open(false)
            get_viewport().set_input_as_handled()
            return

        if event.is_action_pressed("build_menu"):
            _open_build_menu()
            get_viewport().set_input_as_handled()
            return

        if GameOptions.enabled("zoom") and event.is_action_pressed("zoom_in"):
            var zoom_percent = int(world.call("adjust_camera_zoom", 1))
            _show_message("ZOOM %d%%" % zoom_percent)
            get_viewport().set_input_as_handled()
            return

        if GameOptions.enabled("zoom") and event.is_action_pressed("zoom_out"):
            var zoom_percent = int(world.call("adjust_camera_zoom", -1))
            _show_message("ZOOM %d%%" % zoom_percent)
            get_viewport().set_input_as_handled()
            return

        if event.is_action_pressed("start"):
            _queue_start_menu(event)
            get_viewport().set_input_as_handled()
        return

    # Text-entry mode never owns controller focus. If the user navigates away,
    # accept the current text, close the Android keyboard, and continue moving
    # through the menu in the same input press.
    if text_entry_target != "":
        if event.is_action_pressed("move_up"):
            _finish_text_entry(true)
            _move_menu_vertical(-1)
            menu_nav_cooldown = MENU_NAV_DELAY
            get_viewport().set_input_as_handled()
            return

        if event.is_action_pressed("move_down"):
            _finish_text_entry(true)
            _move_menu_vertical(1)
            menu_nav_cooldown = MENU_NAV_DELAY
            get_viewport().set_input_as_handled()
            return

        if event.is_action_pressed("move_left"):
            _finish_text_entry(true)
            _menu_left_right(-1)
            menu_nav_cooldown = MENU_NAV_DELAY
            get_viewport().set_input_as_handled()
            return

        if event.is_action_pressed("move_right"):
            _finish_text_entry(true)
            _menu_left_right(1)
            menu_nav_cooldown = MENU_NAV_DELAY
            get_viewport().set_input_as_handled()
            return

        if event.is_action_pressed("confirm") or event.is_action_pressed("start"):
            _finish_text_entry(true)
            get_viewport().set_input_as_handled()
            return

        if event.is_action_pressed("cancel"):
            _finish_text_entry(true)
            get_viewport().set_input_as_handled()
            return

        # Characters from the Android soft keyboard arrive as key events.
        if event is InputEventKey:
            var key = event as InputEventKey
            if key.pressed and not key.echo:
                if key.keycode == KEY_BACKSPACE:
                    if text_entry_buffer.length() > 0:
                        text_entry_buffer = text_entry_buffer.left(text_entry_buffer.length() - 1)
                        _refresh_text_entry_display()
                    get_viewport().set_input_as_handled()
                    return

                if key.unicode >= 32 and key.unicode != 127:
                    if text_entry_buffer.length() < 24:
                        text_entry_buffer += String.chr(key.unicode)
                        _refresh_text_entry_display()
                    get_viewport().set_input_as_handled()
                    return

        return

    # Restore D-pad / left-stick menu navigation using the EXISTING actions.
    if event.is_action_pressed("move_up"):
        if menu_nav_cooldown <= 0.0:
            if menu_row == MENU_ROW_COLOR and menu_col > 0:
                _change_player_selector(1)
            else:
                _move_menu_vertical(-1)
            menu_nav_cooldown = MENU_NAV_DELAY
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("move_down"):
        if menu_nav_cooldown <= 0.0:
            if menu_row == MENU_ROW_COLOR and menu_col > 0:
                _change_player_selector(-1)
            else:
                _move_menu_vertical(1)
            menu_nav_cooldown = MENU_NAV_DELAY
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("move_left"):
        if menu_nav_cooldown <= 0.0:
            _menu_left_right(-1)
            menu_nav_cooldown = MENU_NAV_DELAY
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("move_right"):
        if menu_nav_cooldown <= 0.0:
            _menu_left_right(1)
            menu_nav_cooldown = MENU_NAV_DELAY
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("confirm"):
        _activate_menu_item()
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("cancel"):
        # Leaving either PLAYER selector returns focus to the PLAYER row so
        # vertical navigation works again.  It must never trap the user in
        # color/model selection.
        if menu_row == MENU_ROW_COLOR and menu_col > 0:
            menu_col = 0
            _update_menu_cursor()
            get_viewport().set_input_as_handled()
        elif not started and not generating:
            # Back to the SINGLE PLAYER / MULTIPLAYER choice.
            coop_game.cancel_join();coop_menu.open()
            get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("start"):
        _start_game()
        get_viewport().set_input_as_handled()

func _menu_context_uses_stick_filter() -> bool:
    if is_instance_valid(coop_game) and is_instance_valid(coop_game.interaction_ui) and coop_game.interaction_ui.visible:return true
    if is_instance_valid(coop_menu) and coop_menu.visible:return true
    if is_instance_valid(waypoint_ui) and waypoint_ui.naming:return true
    if is_instance_valid(game_files_menu) and game_files_menu.visible:return true
    if is_instance_valid(mod_menu_panel) and mod_menu_panel.visible:return true
    if is_instance_valid(bag_action_ui):return true
    # The map and radial wheel poll continuously and need the stick's full
    # range. Row/command menus need deliberate, discrete direction presses.
    if field_move_wheel_open:
        return false
    if game_menu_open and game_menu_detail_open and game_menu_map_screen.visible:
        return false
    return (
        not started
        or mansion_switch_open or wild_pokemon_prompt_open or egg_pickup_open
        or storage_menu_open or trainer_tip_open
        or (is_instance_valid(pokedex_menu) and pokedex_menu.visible)
        or (is_instance_valid(options_menu) and options_menu.visible)
        or setup_load_open
        or pokemon_stats_open
        or touch_config.visible
        or progression_active
        or quit_prompt_open
        or battle_active
        or build_menu_open
        or craft_menu_open
        or game_menu_open
    )

func _menu_stick_event_is_blocked(event: InputEvent) -> bool:
    if not event is InputEventJoypadMotion:
        return false
    var motion := event as InputEventJoypadMotion
    if motion.axis not in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
        return false
    if not _menu_context_uses_stick_filter():
        last_menu_stick_token = 0
        menu_stick_state_by_device.clear()
        return false

    var stick: Vector2 = menu_stick_state_by_device.get(
        motion.device, Vector2.ZERO
    )
    if motion.axis == JOY_AXIS_LEFT_X:
        stick.x = motion.axis_value
    else:
        stick.y = motion.axis_value
    menu_stick_state_by_device[motion.device] = stick
    if stick.length() <= MENU_STICK_RELEASE:
        last_menu_stick_token = 0
        return true
    if stick.length() < MENU_STICK_ACTIVATION:
        return true

    var dominant_axis := (
        JOY_AXIS_LEFT_X if absf(stick.x) >= absf(stick.y)
        else JOY_AXIS_LEFT_Y
    )
    if motion.axis != dominant_axis:
        return true
    var dominant_value := stick.x if dominant_axis == JOY_AXIS_LEFT_X else stick.y
    var direction_sign := -1 if dominant_value < 0.0 else 1
    var token := (1 if dominant_axis == JOY_AXIS_LEFT_X else 2) * direction_sign
    var now := Time.get_ticks_msec()
    if token != last_menu_stick_token:
        if last_menu_stick_token != 0 and now - last_menu_stick_msec < MENU_STICK_REPEAT_MSEC:
            return true
        last_menu_stick_token = token
        last_menu_stick_msec = now
        return false
    if now - last_menu_stick_msec >= MENU_STICK_REPEAT_MSEC:
        last_menu_stick_msec = now
        return false
    return true

func _is_android_touch_runtime() -> bool:
    return OS.has_feature("android") or (
        is_instance_valid(touch_controls)
        and bool(touch_controls.get("android_runtime"))
    )

func _setup_menu_navigation() -> void:
    menu_row = MENU_ROW_LOCAL
    menu_col = 0
    _update_classic_menu_labels()
    _update_menu_cursor()

## Joining someone else's world: the world is theirs, so only the player's look
## is offered. The world rows are hidden and skipped, not just locked.
var join_layout := false
const JOIN_HIDDEN_ROWS := [MENU_ROW_MODE, MENU_ROW_SIZE, MENU_ROW_WORLD_NAME, MENU_ROW_PLAYER_NAME]
const JOIN_HIDDEN_NODES := ["ModeSelectionTick", "ModeLabel", "WorldSizeLabel", "WorldLabel", "WorldEdit", "NameLabel"]
## The PLAYER row is 168 px wide from x=14; this centres it on the 320 px screen.
const JOIN_ROW_SHIFT := 62.0
const JOIN_ROW_NODES := ["AppearanceLabel", "ColorUp", "ColorDown", "PlayerColorSwatch", "ModelUp", "ModelDown", "PlayerPreview"]

var join_info: Label
var join_note: Label

func _set_join_layout(joining: bool) -> void:
    join_layout = joining
    for node_name in JOIN_HIDDEN_NODES:
        (setup_panel.get_node(node_name) as CanvasItem).visible = not joining
    # Where the world rows were: which world this is, then the chosen player's
    # name, then the PLAYER row, all centred.
    if join_info == null:
        join_info = _source_ui_label(setup_panel, "JoinInfo", Vector2(8, 38), Vector2(304, 40), 12, "")
        join_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    if join_note == null:
        join_note = _source_ui_label(setup_panel, "JoinNote", Vector2(8, 21), Vector2(304, 12), 8,
            "PRIVATE STORAGE FOLLOWS YOU INTO ANY WORLD")
        join_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    join_note.visible = joining
    join_info.visible = joining
    if joining:
        var lobby: Dictionary = coop_game.join_lobby
        join_info.text = "JOINING\n%s" % String(lobby.get("name", "WORLD")).to_upper().left(24)
    for node_name in JOIN_ROW_NODES:
        var piece = setup_panel.get_node(node_name) # Controls and one Sprite2D
        if not piece.has_meta("solo_x"):
            piece.set_meta("solo_x", piece.position.x)
        piece.position.x = float(piece.get_meta("solo_x")) + (JOIN_ROW_SHIFT if joining else 0.0)
    if not player_model_name.has_meta("solo_rect"):
        player_model_name.set_meta("solo_rect", Rect2(player_model_name.position, player_model_name.size))
        player_model_name.set_meta("solo_align", player_model_name.horizontal_alignment)
    var name_home: Rect2 = player_model_name.get_meta("solo_rect")
    if joining:
        player_model_name.position = Vector2(8, 84)
        player_model_name.size = Vector2(304, name_home.size.y)
        player_model_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        player_model_name.scale.x = 1.0
    else:
        player_model_name.position = name_home.position
        player_model_name.size = name_home.size
        player_model_name.horizontal_alignment = player_model_name.get_meta("solo_align")
        _fit_player_name()
    if joining and menu_row in JOIN_HIDDEN_ROWS:
        menu_row = MENU_ROW_COLOR
        menu_col = 0
    _update_menu_cursor()

func _move_menu_vertical(direction: int) -> void:
    menu_row = wrapi(menu_row + direction, MENU_ROW_LOCAL, MENU_ROW_GO + 1)
    while join_layout and menu_row in JOIN_HIDDEN_ROWS:
        menu_row = wrapi(menu_row + direction, MENU_ROW_LOCAL, MENU_ROW_GO + 1)

    # Clamp/restore the horizontal choice for each row.
    if menu_row == MENU_ROW_MODE:
        menu_col = 0 if selected_mode == "NEW" else 1
    elif menu_row == MENU_ROW_SIZE:
        menu_col = selected_world_size
    elif menu_row == MENU_ROW_COLOR:
        # Enter the row itself first. Right/Confirm enters its selectors;
        # Left/Cancel returns here, after which Up/Down can leave the row.
        menu_col = 0
    else:
        menu_col = 0

    _update_menu_cursor()
    _update_persistent_selection_ticks()

func _menu_left_right(direction: int) -> void:
    if not coop_game.join_setup_code.is_empty() and menu_row in [MENU_ROW_SIZE,MENU_ROW_MODE]:return
    if menu_row == MENU_ROW_LOCAL:
        return
    if menu_row == MENU_ROW_MODE:
        menu_col = wrapi(menu_col + direction, 0, 2)
        selected_mode = "NEW" if menu_col == 0 else "LOAD"
        _update_classic_menu_labels()
        _update_menu_cursor()
        return

    if menu_row == MENU_ROW_SIZE:
        menu_col = wrapi(menu_col + direction, 0, WORLD_SIZE_NAMES.size())
        selected_world_size = menu_col
        _update_classic_menu_labels()
        _update_menu_cursor()
        return

    if menu_row == MENU_ROW_COLOR:
        menu_col = clampi(menu_col + direction, 0, 2)
        _update_menu_cursor()
        return

    if menu_row == MENU_ROW_WORLD_NAME:
        _begin_text_entry("world")
    elif menu_row == MENU_ROW_PLAYER_NAME:
        _begin_text_entry("player")

func _activate_menu_item() -> void:
    match menu_row:
        MENU_ROW_LOCAL:
            coop_game.cancel_join();coop_menu.open()
        MENU_ROW_MODE:
            if selected_mode == "LOAD":
                menu_status.text = "LOAD READY" if not _find_save_path(world_edit.text.strip_edges()).is_empty() else "NO SAVE FILE"
            else:
                menu_status.text = "NEW WORLD"
        MENU_ROW_SIZE:
            menu_status.text = "WORLD SIZE: %s" % WORLD_SIZE_NAMES[selected_world_size]
        MENU_ROW_WORLD_NAME:
            _begin_text_entry("world")
        MENU_ROW_PLAYER_NAME:
            _begin_text_entry("player")
        MENU_ROW_COLOR:
            if menu_col == 0:
                menu_col = 1
            elif menu_col == 1:
                _next_color()
            elif menu_col == 2:
                _next_model()
        MENU_ROW_GO:
            _start_game()

    _update_menu_cursor()

func _update_classic_menu_labels() -> void:
    var mode_label := $UI/SetupPanel/ModeLabel as Label
    var size_label := $UI/SetupPanel/WorldSizeLabel as Label

    mode_label.text = "NEW        LOAD"
    size_label.text = "WORLD   S   M   L   XL   XXL"

    _update_persistent_selection_ticks()

func _update_persistent_selection_ticks() -> void:
    var mode_tick := $UI/SetupPanel/ModeSelectionTick as Label
    var mode_label := $UI/SetupPanel/ModeLabel as Label

    # Use the same native-pixel alignment on navigation and confirmation.
    var mode_font := mode_label.get_theme_font_size("font_size")
    var load_x := mode_label.position.x + JOHTO_FONT.get_string_size(
        "NEW        ", HORIZONTAL_ALIGNMENT_LEFT, -1, mode_font).x - 10.0
    mode_tick.visible = menu_row == MENU_ROW_MODE
    mode_tick.position.x = 0.0 if selected_mode == "NEW" else roundf(load_x)
    _align_menu_tick(mode_tick, mode_label)


func _update_menu_cursor() -> void:
    var cursor := $UI/SetupPanel/MenuCursor as Label
    var selecting_color := menu_row == MENU_ROW_COLOR and menu_col == 1
    var selecting_model := menu_row == MENU_ROW_COLOR and menu_col == 2
    $UI/SetupPanel/ColorUp.visible = selecting_color
    $UI/SetupPanel/ColorDown.visible = selecting_color
    $UI/SetupPanel/ModelUp.visible = selecting_model
    $UI/SetupPanel/ModelDown.visible = selecting_model
    # On the PLAYER row, the active arrow pair replaces the normal cursor.
    # This prevents an extra triangle appearing between the selectors.
    cursor.visible = menu_row not in [MENU_ROW_GO, MENU_ROW_MODE] and not (
        menu_row == MENU_ROW_COLOR and menu_col > 0
    )
    if setup_go_cursor != null:
        setup_go_cursor.visible = menu_row == MENU_ROW_GO
        var font_size := start_button.get_theme_font_size("font_size")
        var font_height := JOHTO_FONT.get_height(font_size)
        var text_width := JOHTO_FONT.get_string_size(start_button.text,
            HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
        var text_top := start_button.position.y + (start_button.size.y - font_height) / 2.0
        # Align the arrow with the visible GO! glyphs, not the font line box.
        setup_go_cursor.position = Vector2(
            roundf(start_button.position.x + (start_button.size.x - text_width) / 2.0 -
                setup_go_cursor.size.x - 2.0),
            roundf(text_top))

    var pos := Vector2(2, 2)

    match menu_row:
        MENU_ROW_LOCAL:
            # Leave the LOCAL text untouched; add one small source-pixel gap.
            pos = Vector2(roundf(online_label.position.x-10.0),3) if menu_col==1 and is_instance_valid(online_label) else Vector2(0,3)
        MENU_ROW_MODE:
            var mode_label := $UI/SetupPanel/ModeLabel as Label
            var mode_font := mode_label.get_theme_font_size("font_size")
            var load_x := mode_label.position.x + JOHTO_FONT.get_string_size(
                "NEW        ", HORIZONTAL_ALIGNMENT_LEFT, -1, mode_font).x - 10.0
            pos = Vector2(0, 28) if menu_col == 0 else Vector2(roundf(load_x), 26)
        MENU_ROW_SIZE:
            var size_label := $UI/SetupPanel/WorldSizeLabel as Label
            var size_font := size_label.get_theme_font_size("font_size")
            # _update_classic_menu_labels() supplies three-space separators at
            # runtime.  Measure those exact prefixes so M/XL/XXL never overlap
            # their selection triangle.
            var prefixes := [
                "WORLD   ",
                "WORLD   S   ",
                "WORLD   S   M   ",
                "WORLD   S   M   L   ",
                "WORLD   S   M   L   XL   "
            ]
            var option_x := size_label.position.x + JOHTO_FONT.get_string_size(
                prefixes[menu_col], HORIZONTAL_ALIGNMENT_LEFT, -1, size_font).x
            pos = Vector2(roundf(option_x - 10.0), 47)
        MENU_ROW_WORLD_NAME:
            pos = Vector2(2, 70)
        MENU_ROW_PLAYER_NAME:
            pos = Vector2(2, 95)
        MENU_ROW_COLOR:
            pos = Vector2(2.0 + (JOIN_ROW_SHIFT if join_layout else 0.0), 118)
        MENU_ROW_GO:
            pos = Vector2(2, 144)

    cursor.position = pos
    var labels := ["LocalLabel", "ModeLabel", "WorldSizeLabel", "WorldLabel", "NameLabel", "AppearanceLabel"]
    if menu_row >= 0 and menu_row < labels.size():
        _align_menu_tick(cursor, online_label if menu_row==MENU_ROW_LOCAL and menu_col==1 and is_instance_valid(online_label) else setup_panel.get_node(labels[menu_row]))
    _update_persistent_selection_ticks()

func _available_save_entries() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var seen: Dictionary = {}
    if not _ensure_save_directory():
        return result
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_INDEX_PATH) == OK:
        for raw_key in cfg.get_section_keys("worlds"):
            var indexed_path := _indexed_save_path(String(cfg.get_value("worlds", String(raw_key), "")))
            var indexed_data := _read_save_file(indexed_path)
            if indexed_data.is_empty() or seen.has(indexed_path):
                continue
            seen[indexed_path] = true
            result.append({"path":indexed_path, "data":indexed_data})
    var directory := DirAccess.open(SAVE_DIR)
    if directory != null:
        directory.list_dir_begin()
        var file_name := directory.get_next()
        while not file_name.is_empty():
            if not directory.current_is_dir() and file_name.to_lower().ends_with(".json"):
                var candidate := "%s/%s" % [SAVE_DIR, file_name]
                var candidate_data := _read_save_file(candidate)
                if not candidate_data.is_empty() and not seen.has(candidate):
                    seen[candidate] = true
                    result.append({"path":candidate, "data":candidate_data})
            file_name = directory.get_next()
        directory.list_dir_end()
    result.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
        return int(FileAccess.get_modified_time(String(first.path))) > \
            int(FileAccess.get_modified_time(String(second.path))))
    return result

func _open_setup_load_selector() -> void:
    setup_load_entries = _available_save_entries()
    if setup_load_entries.is_empty():
        menu_status.text = "NO SAVE FILE"
        return
    setup_load_index = 0
    setup_load_open = true
    setup_panel.visible = false
    setup_load_panel.visible = true
    _refresh_setup_load_selector()

func _refresh_setup_load_selector() -> void:
    if setup_load_entries.is_empty():
        setup_load_name.text = "NO SAVE"
        return
    setup_load_index = wrapi(setup_load_index, 0, setup_load_entries.size())
    var data := setup_load_entries[setup_load_index].data as Dictionary
    var world_name := String(data.get("world_name", "default")).strip_edges()
    if world_name.is_empty():
        world_name = "default"
    setup_load_name.text = "%s.sav" % world_name
    setup_load_name.tooltip_text = setup_load_name.text

func _handle_setup_load_input(event: InputEvent) -> void:
    if event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
        setup_load_index = wrapi(setup_load_index - 1, 0, setup_load_entries.size())
        _refresh_setup_load_selector()
    elif event.is_action_pressed("move_right") or event.is_action_pressed("move_down"):
        setup_load_index = wrapi(setup_load_index + 1, 0, setup_load_entries.size())
        _refresh_setup_load_selector()
    elif event.is_action_pressed("confirm") or event.is_action_pressed("start"):
        var entry := setup_load_entries[setup_load_index]
        var data := entry.data as Dictionary
        setup_load_path = String(entry.path)
        world_edit.text = String(data.get("world_name", world_edit.text))
        selected_world_size = clampi(int(data.get("world_size", selected_world_size)),
            0, WORLD_SIZE_NAMES.size() - 1)
        setup_load_open = false
        setup_load_panel.visible = false
        setup_load_committed = true
        _start_game()
    elif event.is_action_pressed("cancel"):
        setup_load_open = false
        setup_load_panel.visible = false
        setup_panel.visible = true
    else:
        return
    get_viewport().set_input_as_handled()

func _start_game() -> void:
    if started or generating:
        return

    if not coop_game.join_setup_code.is_empty() and not coop_game.active:
        await coop_game.choose("JOIN",coop_game.join_setup_code)
        return

    if coop_game.new_setup_pending and not coop_game.active:
        if selected_mode=="LOAD":
            coop_menu.open();await coop_game.choose("LIST","")
        else:
            await coop_game.choose("NEW","")
        return

    if selected_mode == "LOAD" and not setup_load_committed and not coop_game.active:
        _open_setup_load_selector()
        return

    generating = true
    setup_load_committed = false
    _save_setup()
    _hide_virtual_keyboard()

    setup_panel.visible = false
    generation_panel.visible = true
    generation_status.text = (
        "LOADING...\nPLEASE WAIT..."
        if selected_mode == "LOAD"
        else "Generating...\nPlease wait..."
    )
    generation_tip_index = -1
    generation_tip_timer = 0.0
    _show_generation_tip()

    world.visible = true

    var world_name := world_edit.text.strip_edges()
    if world_name.is_empty():
        world_name = "PokeWilds"

    var seed_value: int
    var load_data = {}

    if selected_mode == "NEW":
        GameOptions.restore_game_options({},world_name,true)
        _apply_game_options()
        preferred_storage_box = ""
        map_waypoints.clear()
        adjacent_worlds.clear()
        current_world_grid = Vector2i.ZERO
        inventory = CraftingData.ensure_inventory(STARTING_INVENTORY)
        caught_pokemon = [_make_starter_machop()]
        caught_species = ["machop"]
        pokedex_progress.restore({})
        pokedex_progress.seed_owned(caught_pokemon)
        new_world_sequence += 1
        var seed_rng := RandomNumberGenerator.new()
        seed_rng.randomize()
        seed_value = (
            world_name.hash()
            ^ int(Time.get_unix_time_from_system() * 1000000.0)
            ^ Time.get_ticks_usec()
            ^ seed_rng.randi()
            ^ (new_world_sequence * 0x45D9F3B)
        )
    else:
        load_data = coop_game.pending_game.duplicate(true) if coop_game.active else (
            _read_save_file(setup_load_path)
            if not setup_load_path.is_empty()
            else _read_game_save(world_name)
        )
        setup_load_path = ""
        if load_data.is_empty():
            generation_panel.visible = false
            setup_panel.visible = true
            generating = false
            menu_status.text = "NO SAVE FILE"
            return
        seed_value = int(load_data.get("world_seed", 81102))
        selected_world_size = int(load_data.get("world_size", selected_world_size))

    if selected_mode == "LOAD":
        GameOptions.restore_game_options(load_data.get("options", {}),String(load_data.get("world_name",world_name)))
    var gen3 := load("res://scripts/gen3_overhaul.gd")
    if GameOptions.enabled("gen3_overhaul") != gen3.enabled:
        if not await gen3.apply(GameOptions.enabled("gen3_overhaul"),get_tree()):
            generation_panel.hide();setup_panel.show();generating=false
            menu_status.text="OVERHAUL COULD NOT LOAD"
            return
        player_appearance_texture_cache.clear()
        _apply_player_appearance()

    if seed_value == 0:
        seed_value = 81102

    generation_status.text = (
        "LOADING...\nPLEASE WAIT..."
        if selected_mode == "LOAD"
        else "Generating...\nPlease wait..."
    )

    await world.generate_world(
        seed_value, selected_world_size, selected_mode == "LOAD"
    )
    if not world.generation_error.is_empty():
        generation_panel.hide()
        setup_panel.show()
        generating = false
        menu_status.text = "GENERATION FAILED"
        _show_message(world.generation_error)
        return

    _apply_world_player_textures()

    if selected_mode == "LOAD" and not load_data.is_empty():
        await _restore_game_save(load_data)
    if not coop_game.active:
        var loading: bool = selected_mode == "LOAD" and not load_data.is_empty()
        var held = pokemon_storage.get(SHARED_STORAGE_KEY, [])
        var adopted: Dictionary = preload("res://scripts/shared_storage.gd").adopt(
            {SHARED_STORAGE_KEY: held if held is Array else []} if loading else {},
            loading and bool(load_data.get("storage_shared", false)),
            int(load_data.get("storage_serial", 0)) if loading else 0)
        var shared_box = adopted.storage.get(SHARED_STORAGE_KEY, [])
        pokemon_storage[SHARED_STORAGE_KEY] = shared_box if shared_box is Array else []
        shared_storage_serial = int(adopted.serial)
        pokedex_progress.seed_owned(pokemon_storage[SHARED_STORAGE_KEY])

    _ensure_machop_lead(false)
    world.call("clear_active_field_move", false)
    await _warm_map_cache()

    if coop_game.active and not await coop_game.game_started():
        generation_panel.hide();setup_panel.show();generating=false
        # Leave properly and say so. Returning to this screen alone kept the
        # link to the host open and the loaded world's music playing, with no
        # word of what had gone wrong.
        if coop_game.active:
            coop_game.end_session("THE HOST DID NOT ANSWER.\nTRY AGAIN." if not coop_game.hosting else "ONLINE GAME COULD NOT START.")
        return
    generation_panel.visible = false
    started = true
    generating = false
    touch_controls.set_game_active(true)
    _show_message("Welcome, %s!" % player_model_name.text.strip_edges() if overflow_recovery_notice.is_empty() else overflow_recovery_notice)
    overflow_recovery_notice = ""

func _save_setup() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("setup", "player_name", player_model_name.text.strip_edges())
    cfg.set_value("setup", "player_name_custom", not custom_player_name.is_empty())
    cfg.set_value("setup", "world_name", world_edit.text.strip_edges())
    cfg.set_value("setup", "player_color", player_color_index)
    cfg.set_value("setup", "player_model", player_model_index)
    cfg.set_value("setup", "mode", selected_mode)
    cfg.set_value("setup", "world_size", selected_world_size)
    cfg.save(SETUP_SAVE_PATH)

func _load_setup() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SETUP_SAVE_PATH) == OK:
        world_edit.text = str(cfg.get_value("setup", "world_name", "PokeWilds"))
        player_color_index = clampi(int(cfg.get_value("setup", "player_color", 0)), 0, PLAYER_TEXTURES.size() - 1)
        player_model_index = clampi(
            int(cfg.get_value("setup", "player_model", 0)),
            0,
            _player_model_count() - 1
        )
        custom_player_name = str(cfg.get_value("setup","player_name","")).strip_edges().left(24) if bool(cfg.get_value("setup","player_name_custom",false)) else ""
        selected_mode = str(cfg.get_value("setup", "mode", "NEW"))
        selected_world_size = clampi(int(cfg.get_value("setup", "world_size", 1)), 0, WORLD_SIZE_NAMES.size() - 1)

    var newest := _find_newest_valid_save()
    if not newest.is_empty():
        var data := _read_save_file(newest)
        if not data.is_empty():
            world_edit.text = String(data.get("world_name", world_edit.text))

    _update_classic_menu_labels()

func _on_generation_progress(value: float, message: String) -> void:
    if edge_travel_busy:
        return # Travel presentation is independent of the NEW/LOAD setup choice.
    var _unused_progress := value
    var _unused_message := message
    generation_status.text = (
        "LOADING...\nPLEASE WAIT..."
        if selected_mode == "LOAD"
        else "Generating...\nPlease wait..."
    )

func _show_generation_tip() -> void:
    if SourceEventData.TRAINER_TIPS.is_empty():
        return
    var next_index := battle_rng.randi_range(0, SourceEventData.TRAINER_TIPS.size() - 1)
    if SourceEventData.TRAINER_TIPS.size() > 1 and next_index == generation_tip_index:
        next_index = (next_index + 1) % SourceEventData.TRAINER_TIPS.size()
    generation_tip_index = next_index
    generation_tip_title.text = "- Trainer Tips -"
    generation_tip_text.text = _format_generation_tip(
        String(SourceEventData.TRAINER_TIPS[generation_tip_index])
    )
    generation_tip_timer = GENERATION_TIP_SECONDS

func _format_generation_tip(tip: String) -> String:
    var words := tip.strip_edges().split(" ", false)
    if words.size() < 2:
        return tip
    var line_count := 3 if tip.length() > 64 else 2
    var lines: Array[String] = []
    var start := 0
    for line_index in range(line_count):
        var words_left := words.size() - start
        var lines_left := line_count - line_index
        if lines_left <= 1:
            var final_line := ""
            for word_index in range(start, words.size()):
                final_line += (
                    " " if not final_line.is_empty() else ""
                ) + String(words[word_index])
            lines.append(final_line)
            break
        var remaining_length := 0
        for word_index in range(start, words.size()):
            remaining_length += String(words[word_index]).length()
        remaining_length += maxi(0, words_left - 1)
        var target_length := ceili(float(remaining_length) / float(lines_left))
        var line := ""
        while start < words.size() - (lines_left - 1):
            var word := String(words[start])
            var candidate := line + (" " if not line.is_empty() else "") + word
            if not line.is_empty() and candidate.length() > target_length:
                break
            line = candidate
            start += 1
        lines.append(line)
    return "\n".join(lines)

func _two_line_generation_tip(tip: String) -> String:
    # Compatibility helper for older QA entry points.
    return _format_generation_tip(tip)

func _make_starter_machop() -> Dictionary:
    return BattleEngine.make_pokemon("machop", 5, battle_rng, {
        "original_trainer": player_model_name.text.strip_edges(),
        "met_location": "STARTING SHORE"
    })

func _ensure_machop_lead(heal_after_whiteout: bool) -> void:
    # Keep the existing repair for malformed records, without adding/reordering Pokemon.
    for index in range(caught_pokemon.size() - 1, -1, -1):
        if typeof(caught_pokemon[index]) == TYPE_DICTIONARY and String(
                caught_pokemon[index].get("species", "")).is_empty():
            caught_pokemon.remove_at(index)
    if not heal_after_whiteout: return
    for index in range(caught_pokemon.size()):
        var pokemon: Dictionary = caught_pokemon[index]
        if bool(pokemon.get("is_egg", false)): continue
        # CheckWhitedOut: HP only; status/PP and party ordering are retained.
        pokemon["hp"] = int(int(pokemon.get("max_hp", 1)) / 2)
        caught_pokemon[index] = pokemon

func _previous_color() -> void:
    player_color_index = wrapi(player_color_index - 1, 0, PLAYER_TEXTURES.size())
    _apply_player_appearance()

func _next_color() -> void:
    player_color_index = wrapi(player_color_index + 1, 0, PLAYER_TEXTURES.size())
    _apply_player_appearance()

func _player_model_count() -> int:
    return PLAYER_MODEL_NAMES.size()

func _previous_model() -> void:
    player_model_index = wrapi(
        player_model_index - 1, 0, _player_model_count()
    )
    _apply_player_appearance()

func _next_model() -> void:
    player_model_index = wrapi(
        player_model_index + 1, 0, _player_model_count()
    )
    _apply_player_appearance()

func _change_player_selector(direction: int) -> void:
    if menu_col == 1:
        if direction > 0:
            _next_color()
        else:
            _previous_color()
    elif menu_col == 2:
        if direction > 0:
            _next_model()
        else:
            _previous_model()

func _apply_player_color(index: int) -> void:
    player_color_index = clampi(index, 0, PLAYER_COLOR_VALUES.size() - 1)
    _apply_player_appearance()

func _apply_player_appearance() -> void:
    player_color_index = clampi(
        player_color_index, 0, PLAYER_COLOR_VALUES.size() - 1
    )
    player_model_index = clampi(
        player_model_index, 0, _player_model_count() - 1
    )
    player_model_name.text = custom_player_name if not custom_player_name.is_empty() else PLAYER_MODEL_NAMES[player_model_index].to_upper()
    _fit_player_name()
    player_preview.texture = _player_appearance_texture(false)
    player_preview.hframes = 8
    player_preview.frame = 0
    player_color_swatch.texture = _recolor_texture(
        preload("res://assets/source_exact/global/select_color1.png"),
        Color.WHITE,
        PLAYER_COLOR_VALUES[player_color_index],
        "swatch:%d" % player_color_index
    )

func _player_appearance_texture(running: bool) -> Texture2D:
    var base: Texture2D = (
        PLAYER_MODEL_RUN_TEXTURES[player_model_index]
        if running
        else PLAYER_MODEL_WALK_TEXTURES[player_model_index]
    )
    return _recolor_texture(
        base,
        PLAYER_MODEL_REPLACE_COLORS[player_model_index],
        PLAYER_COLOR_VALUES[player_color_index],
        "%s:%d:%d" % ["run" if running else "walk", player_model_index,
            player_color_index]
    )

func _player_sitting_texture(frame: int = 0) -> Texture2D:
    var texture := _recolor_texture(
        PLAYER_MODEL_SITTING_TEXTURES[player_model_index],
        PLAYER_MODEL_REPLACE_COLORS[player_model_index],
        PLAYER_COLOR_VALUES[player_color_index],
        "sitting:%d:%d" % [player_model_index, player_color_index])
    # Java Player.Sitting: front pose for stools/couch1, side pose for couch2-5.
    return _source_texture_region(texture, Rect2(clampi(frame, 0, 2) * 16, 0, 16, 16))

func _player_sleeping_texture() -> Texture2D:
    var recolored := _recolor_texture(
        PLAYER_MODEL_SLEEP_TEXTURES[player_model_index],
        PLAYER_MODEL_REPLACE_COLORS[player_model_index],
        PLAYER_COLOR_VALUES[player_color_index],
        "sleep:%d:%d" % [player_model_index, player_color_index]
    )
    # Summer's source image is 24 px high, while the Java renderer uses the
    # same 24x16 sleeping region as every other character.
    if recolored.get_height() <= 16:
        return recolored
    var source_region := AtlasTexture.new()
    source_region.atlas = recolored
    source_region.region = Rect2(0, 0, 24, 16)
    return source_region

func _recolor_texture(
        base: Texture2D, source_color: Color, target_color: Color,
        cache_key: String
    ) -> Texture2D:
    if player_appearance_texture_cache.has(cache_key):
        return player_appearance_texture_cache[cache_key] as Texture2D
    # Imported textures can share their decoded Image. Work on a copy so one
    # chosen color never contaminates another model/color cache entry.
    var overhaul := preload("res://scripts/gen3_overhaul.gd")
    if overhaul.enabled and not overhaul.user_paths.has(base.resource_path):
        if base.resource_path.begins_with("res://assets/source_exact/player/red/"):
            source_color = Color8(248,112,88) if base.resource_path.ends_with("back.png") else Color8(192,56,56)
        elif base.resource_path.begins_with("res://assets/source_exact/player/may-"):
            source_color = Color8(197,65,65) if base.resource_path.ends_with("back.png") else Color8(185,54,54)
    var image := Image.new()
    image.copy_from(base.get_image())
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var pixel := image.get_pixel(x, y)
            if (pixel.r8 == source_color.r8 and pixel.g8 == source_color.g8
                    and pixel.b8 == source_color.b8 and pixel.a8 > 0):
                image.set_pixel(
                    x, y, Color(target_color.r, target_color.g,
                        target_color.b, pixel.a)
                )
    var texture := ImageTexture.create_from_image(image)
    player_appearance_texture_cache[cache_key] = texture
    return texture

func _apply_world_player_textures() -> void:
    var player_node := world.get_node_or_null("Player")
    if player_node != null and player_node.has_method("set_character_textures"):
        player_node.call(
            "set_character_textures",
            _player_appearance_texture(false),
            _player_appearance_texture(true)
        )
        return
    var player_sprite := world.get_node_or_null("Player/Sprite2D") as Sprite2D
    if player_sprite != null:
        player_sprite.texture = _player_appearance_texture(false)
        player_sprite.hframes = 8
        player_sprite.frame = 0

func _display_field_gui_input(event: InputEvent, target: String) -> void:
    # Touching/clicking the field opens Android keyboard WITHOUT focusing LineEdit.
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            _begin_text_entry(target)
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.pressed:
            _begin_text_entry(target)
            get_viewport().set_input_as_handled()

func _begin_text_entry(target: String) -> void:
    if target=="world" and not coop_game.join_setup_code.is_empty():return
    if target not in ["world", "player"]:
        return
    text_entry_target = target
    text_entry_buffer = world_edit.text if target == "world" else player_model_name.text
    menu_row = MENU_ROW_WORLD_NAME if target == "world" else MENU_ROW_PLAYER_NAME

    _refresh_text_entry_display()
    _show_virtual_keyboard_custom()

func _finish_text_entry(accept: bool) -> void:
    if text_entry_target == "":
        return

    if text_entry_target == "player":
        if accept:
            var entered := text_entry_buffer.strip_edges().left(24)
            custom_player_name = "" if entered.to_upper() == PLAYER_MODEL_NAMES[player_model_index].to_upper() else entered
        player_model_name.text = custom_player_name if not custom_player_name.is_empty() else PLAYER_MODEL_NAMES[player_model_index].to_upper()
        _fit_player_name()
    elif accept:
        world_edit.text = text_entry_buffer

    text_entry_target = ""
    text_entry_buffer = ""
    _hide_virtual_keyboard()
    menu_nav_cooldown = MENU_NAV_DELAY
    _update_menu_cursor()

func _fit_player_name() -> void:
    if join_layout:
        player_model_name.scale.x = 1.0
        return
    var width := player_model_name.get_theme_font("font").get_string_size(player_model_name.text,HORIZONTAL_ALIGNMENT_LEFT,-1,player_model_name.get_theme_font_size("font_size")).x
    player_model_name.scale.x = minf(1.0,210.0/maxf(1.0,width))

func _refresh_text_entry_display() -> void:
    if text_entry_target == "world":
        world_edit.text = text_entry_buffer
    elif text_entry_target == "player":
        player_model_name.text = text_entry_buffer
        _fit_player_name()

func _show_virtual_keyboard_custom() -> void:
    if not OS.has_feature("mobile"):
        return

    DisplayServer.virtual_keyboard_show(
        text_entry_buffer,
        Rect2i(),
        DisplayServer.KEYBOARD_TYPE_DEFAULT,
        24,
        text_entry_buffer.length(),
        text_entry_buffer.length()
    )

func _hide_virtual_keyboard() -> void:
    if OS.has_feature("mobile"):
        DisplayServer.virtual_keyboard_hide()

func _current_battle_terrain() -> String:
    var player_node := world.get_node_or_null("Player") as Node2D
    if player_node == null:
        return "GRASSY"
    var cell := Vector2i(
        int(floor(player_node.position.x / 16.0)),
        int(floor(player_node.position.y / 16.0))
    )
    if world.has_method("battle_terrain_at"):
        return String(world.call("battle_terrain_at", cell))
    return "GRASSY"

func _on_encounter_requested(species: String, level: int) -> void:
    if is_instance_valid(coop_game) and coop_game.active and coop_game.building.collecting:
        coop_game.building.field_encounter={"species":species,"level":level,"record":world.pending_encounter_record.duplicate(true)}
        return
    _start_battle_context({
        "id": "wild", "kind": "wild", "can_run": true,
        "can_catch": true,
        "party": [{"species": species, "level": level}]
    })

func _on_battle_requested(context: Dictionary) -> void:
    var event_id := String(context.get("id", ""))
    # Tile/PlayerStanding use ! for a bite, a ghost, an animated doll or tree.
    var source_alert := bool(context.get("source_player_alert", false)) or (
        event_id.begins_with("ghost") or event_id.begins_with("sudowoodo_tree_")
        or event_id in ["doll_banette", "doll_mimikyu"])
    _start_battle_context(context, source_alert)

func _party_reference_level() -> int:
    var levels: Array[int] = []
    for raw_pokemon in caught_pokemon:
        if typeof(raw_pokemon) != TYPE_DICTIONARY:
            continue
        var pokemon := raw_pokemon as Dictionary
        if bool(pokemon.get("is_egg", false)):
            continue
        levels.append(maxi(1, int(pokemon.get("level", 1))))
    if levels.is_empty():
        return 5
    levels.sort()
    var middle := levels.size() / 2
    if levels.size() % 2 == 1:
        return levels[middle]
    return roundi((levels[middle - 1] + levels[middle]) * 0.5)

func wild_level_for_player(source_level: int) -> int:
    var reference_level := _party_reference_level()
    return clampi(
        maxi(1, source_level),
        maxi(2, reference_level - 3),
        mini(100, reference_level + 1)
    )

func _prepare_battle_context(context: Dictionary) -> Dictionary:
    var prepared := context.duplicate(true)
    if bool(prepared.get("fixed_level",false)) or bool(prepared.get("source_unown", false)) or String(prepared.get("id", "")).begins_with("source_night_"):
        # SpawnGhost/Cacturnt supply authored levels, not scaled wild spawns.
        return prepared
    if String(prepared.get("kind", "wild")) != "wild":
        return prepared
    var raw_party = prepared.get("party", [])
    if typeof(raw_party) != TYPE_ARRAY:
        return prepared
    var scaled_party: Array = []
    var scaled_any := false
    for raw_member in raw_party as Array:
        if typeof(raw_member) != TYPE_DICTIONARY:
            continue
        var member := (raw_member as Dictionary).duplicate(true)
        var source_level := maxi(1, int(member.get("level", 1)))
        var scaled_level := wild_level_for_player(source_level)
        member["level"] = scaled_level
        if scaled_level != source_level:
            # Let the battle engine rebuild a legal move set at the adjusted
            # level rather than importing attacks from the high-level source.
            member.erase("moves")
            member.erase("pp")
            member["met_level"] = scaled_level
            scaled_any = true
        scaled_party.append(member)
    prepared["party"] = scaled_party
    prepared["_wild_level_scaled"] = scaled_any
    return prepared

func _start_battle_context(context: Dictionary, source_alert: bool = false) -> void:
    if battle_active or battle_entry_pending:
        return

    var prepared_context = _prepare_battle_context(context)
    var raw_party = prepared_context.get("party", [])
    if typeof(raw_party) != TYPE_ARRAY or (raw_party as Array).is_empty():
        return
    if caught_pokemon.is_empty():
        if coop_game.active and coop_game.raids.eligible(prepared_context):
            _show_message("You need a Pokemon to fight in this raid.")
            return
        if coop_game.active and coop_game.events.eligible(prepared_context):
            if not await coop_game.events.begin(prepared_context):return
        if build_menu_open:
            _close_build_menu()
        safari_ui = preload("res://scripts/source_safari_encounter.gd").new()
        $UI.add_child(safari_ui)
        await safari_ui.start(self, prepared_context, source_alert)
        return
    # Reserve input before any await: a held/released wheel must not reopen
    # movement or activate a field move over the encounter/progression screen.
    battle_entry_pending = true
    if coop_game.active and coop_game.events.eligible(prepared_context):
        if not await coop_game.events.begin(prepared_context):
            battle_entry_pending=false;world.set_gameplay_enabled(true);return
    if coop_game.active and coop_game.raids.eligible(prepared_context):
        if not await coop_game.raids.begin(prepared_context):
            battle_entry_pending=false;world.set_gameplay_enabled(true);return
        raw_party=prepared_context.party
    if build_menu_open:
        _close_build_menu()
    _close_field_move_wheel(false)
    world.set_gameplay_enabled(false)
    while progression_active or mansion_switch_open:
        await get_tree().process_frame
    if source_alert:
        world._show_ecology_emote(world.player.sprite, "!")
        await get_tree().create_timer(60.0 / 60.0).timeout
    battle_exp_participants.clear()
    battle_context = prepared_context
    world.environment_system.prepare_battle_music(battle_context)
    battle_enemy_party = (raw_party as Array).duplicate(true)
    battle_enemy_party_index = 0
    battle_enemy_action_count = 0
    battle_is_double = String(context.get("battle_format", "single")) == "double" and \
        (raw_party as Array).size() >= 2
    battle_player_partner.clear()
    battle_enemy_partner.clear()
    battle_partner_party_index = -1
    battle_enemy_partner_party_index = -1
    battle_double_command_slot = 0
    battle_double_actions.clear()
    battle_double_pending_move = ""
    battle_double_replacement_slot = -1
    battle_result_sent = false
    battle_player_cry_played = false
    if bool(battle_context.get("requires_silph_scope", false)):
        var revealed = bool(battle_context.get("ghost_revealed", false))
        battle_context["ghost_revealed"] = revealed
        if not revealed:
            battle_context["can_catch"] = false
    var first_member = battle_enemy_party[0] as Dictionary
    var species = String(first_member.get("species", "rattata")).to_lower()
    var level = maxi(1, int(first_member.get("level", 1)))

    battle_active = true
    battle_entry_pending = false
    battle_turn_busy = false
    battle_move_index = 0
    battle_command_index = 0
    battle_ui_mode = "INTRO"
    _update_battle_command_cursor()
    battle_run_attempts = 0
    battle_turn_count = 0
    _close_battle_submenu()
    battle_pending_item = ""
    battle_item_pocket_open = false
    battle_item_pocket_index = ItemData.POCKET_ITEMS
    battle_item_menu_names.clear()
    battle_item_menu_index = 0
    item_pocket_menu.visible = false
    battle_field = {
        "weather":"", "weather_turns":0,
        "time_of_day":"night" if world.environment_system.is_night_time() else "day",
        "terrain":String(battle_context.get("terrain", _current_battle_terrain())),
        "player_spikes":0, "enemy_spikes":0
    }
    current_species = species
    current_level = level
    world.set_gameplay_enabled(false)
    var mewtwo_route_volumes: Array[float] = []
    if bool(battle_context.get("source_mewtwo", false)):
        battle_turn_busy = true
        for music_player in world.environment_system.music_players:
            mewtwo_route_volumes.append(music_player.volume_db)
            if music_player.playing:
                var fade := create_tween()
                fade.tween_property(music_player,"volume_linear",0.0,maxf(1.0/60.0,music_player.volume_linear/0.025/60.0))
        var prelude_start := preload("res://scripts/game_clock.gd").ticks_usec()
        while preload("res://scripts/game_clock.gd").ticks_usec()-prelude_start < 333333:
            await get_tree().process_frame
        _show_message("...")
        while preload("res://scripts/game_clock.gd").ticks_usec()-prelude_start < 2000000:
            await get_tree().process_frame
        message_panel.hide()
        message_timer=0.0
    if String(battle_context.get("source_boss", "")) == "regigigas":
        battle_turn_busy=true
        _show_message("...")
        for music_player in world.environment_system.music_players:
            mewtwo_route_volumes.append(music_player.volume_db)
            if music_player.playing:
                create_tween().tween_property(music_player,"volume_linear",0.0,75.0/60.0)
        var regi_deadline := preload("res://scripts/game_clock.gd").ticks_usec()+2750000 # 75 fade + 90 wait ticks
        while preload("res://scripts/game_clock.gd").ticks_usec()<regi_deadline:await get_tree().process_frame
        message_panel.hide()
        message_timer=0.0
    if world.has_method("set_environment_battle_active"):
        world.call("set_environment_battle_active", true)
    for music_index in range(mewtwo_route_volumes.size()):
        world.environment_system.music_players[music_index].volume_db=mewtwo_route_volumes[music_index]
    touch_config.visible = false

    battle_enemy = _make_context_enemy(first_member)
    battle_enemy_party[0] = battle_enemy
    battle_enemy = _apply_pending_wild_record(battle_enemy, level)
    battle_enemy_party[0] = battle_enemy
    if coop_game.active and coop_game.raids.active:coop_game.raids.apply_hp()
    BattleEngine.reset_battle_state(battle_enemy)
    battle_party_index = _first_healthy_party_index()
    if is_instance_valid(ball_mechanics) and not ball_mechanics.requested_battler.is_empty():
        for index in range(caught_pokemon.size()):
            if str(caught_pokemon[index].get("party_ecology_id","")) == ball_mechanics.requested_battler and int(caught_pokemon[index].get("hp",0))>0:
                battle_party_index = index
                break
        ball_mechanics.requested_battler = ""
    if battle_party_index < 0:
        battle_panel.visible = true
        await _type_battle_text("You have no Pokemon able to battle.")
        await get_tree().create_timer(0.4).timeout
        _end_battle("whiteout")
        return
    battle_player = BattleEngine.ensure_pokemon(caught_pokemon[battle_party_index])
    BattleEngine.reset_battle_state(battle_player)
    caught_pokemon[battle_party_index] = battle_player
    battle_exp_participants.append(battle_party_index)
    if battle_is_double:
        var partner_choices = _healthy_party_indices(true)
        if partner_choices.is_empty():
            battle_is_double = false
        else:
            battle_partner_party_index = partner_choices[0]
            battle_exp_participants.append(battle_partner_party_index)
            battle_player_partner = BattleEngine.ensure_pokemon(
                caught_pokemon[battle_partner_party_index])
            BattleEngine.reset_battle_state(battle_player_partner)
            caught_pokemon[battle_partner_party_index] = battle_player_partner
            battle_enemy_partner_party_index = 1
            var enemy_partner_member = battle_enemy_party[1] as Dictionary
            battle_enemy_partner = _make_context_enemy(enemy_partner_member)
            BattleEngine.reset_battle_state(battle_enemy_partner)
            battle_enemy_party[1] = battle_enemy_partner
    var entry_messages: Array[String] = []
    var player_actives: Array = [battle_player]
    var enemy_actives: Array = [battle_enemy]
    if battle_is_double:
        player_actives.append(battle_player_partner)
        enemy_actives.append(battle_enemy_partner)
    var enemy_entry = BattleEngine.switch_in_message(battle_enemy, player_actives, battle_field)
    var player_entry = BattleEngine.switch_in_message(battle_player, enemy_actives, battle_field)
    if not enemy_entry.is_empty(): entry_messages.append(enemy_entry)
    if not player_entry.is_empty(): entry_messages.append(player_entry)
    if battle_is_double:
        var enemy_partner_entry = BattleEngine.switch_in_message(
            battle_enemy_partner, player_actives, battle_field)
        var player_partner_entry = BattleEngine.switch_in_message(
            battle_player_partner, enemy_actives, battle_field)
        if not enemy_partner_entry.is_empty(): entry_messages.append(enemy_partner_entry)
        if not player_partner_entry.is_empty(): entry_messages.append(player_partner_entry)
    battle_context["_entry_messages"] = entry_messages.duplicate()

    var battle_texture: Texture2D = PokemonData.record_texture(battle_enemy, "front")
    if battle_texture == null:
        battle_texture = POKEMON_TEXTURES.get(species) as Texture2D
    if String(battle_context.get("kind", "")) == "ghost" and not bool(battle_context.get("ghost_revealed", true)):
        battle_texture = _ghost_battle_texture()
    enemy_sprite.texture = _battle_sprite_frame(battle_texture)
    player_battle_sprite.texture = _trainer_battle_texture()
    enemy_sprite.visible = true
    player_battle_sprite.visible = true
    enemy_sprite.modulate = Color.WHITE
    player_battle_sprite.modulate = Color.WHITE
    _show_battle_intro_screen()
    battle_status.text = ""
    battle_status.visible_characters = -1
    battle_text_busy = false
    battle_ui_mode = "TRANSITION"
    battle_panel.visible = false
    _set_double_battle_layout()
    _update_battle_field_visuals()
    _update_battle_hud()
    if not String(battle_context.get("source_boss", "")).is_empty():
        await _play_source_boss_intro()
        return
    if bool(battle_context.get("source_mewtwo", false)):
        await _play_source_mewtwo_intro()
        await _play_source_mewtwo_sendout()
        return
    else:
        await _play_battle_transition()
    if bool(battle_context.get("pvp",false)):
        _show_battle_intro_screen()
        return
    if PokemonData.is_shiny(battle_enemy) and not (String(battle_context.get("kind", "")) == "ghost" and not bool(battle_context.get("ghost_revealed", true))):
        await _play_source_battle_feedback("SHINY", false, {})
    if bool(battle_enemy.get("is_ghost", false)):
        source_effect_playing = true
        await _play_source_ghost_intro(true)
        source_effect_playing = false
    else:
        _play_pokemon_cry(battle_enemy)
        if String(battle_enemy.get("species", "")) == "mew":
            await _play_mew_battle_intro()
    _show_battle_intro_screen()

func _play_mew_battle_intro() -> void:
    if not GameOptions.enabled("battle_animations"): return
    var frames: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/mew_intro_frames.json"))
    var texture := PokemonData.record_texture(battle_enemy,"front")
    var elapsed := 0.0
    source_effect_playing = true
    while battle_active and int(elapsed*60.0) < frames.size():
        enemy_sprite.texture = _battle_sprite_frame_at(texture,int(frames[int(elapsed*60.0)]))
        await get_tree().process_frame
        elapsed += get_process_delta_time()
    enemy_sprite.texture = _battle_sprite_frame(texture)
    source_effect_playing = false

var source_boss_sendout_finished := false

func _play_source_boss_intro() -> void:
    battle_turn_busy=true
    source_boss_action_count=0
    _show_battle_intro_screen()
    _start_battle_text("")
    var kind := String(battle_context.source_boss)
    if kind=="regigigas" and GameOptions.enabled("battle_animations"):
        battle_panel.hide()
        var deadline := preload("res://scripts/game_clock.gd").ticks_usec()+int(190.0*1000000.0/60.0)
        while preload("res://scripts/game_clock.gd").ticks_usec()<deadline:await get_tree().process_frame
    await _play_battle_transition(123 if kind=="regigigas" else 154)
    source_boss=preload("res://scripts/source_boss_battle.gd").new()
    battle_panel.add_child(source_boss)
    battle_panel.move_child(source_boss,1)
    source_boss.setup(self,kind,bool(battle_enemy.get("shiny",false)))
    source_boss.special_damage_due.connect(_source_regigigas_damage)
    source_boss_sendout_finished=false
    source_boss.sendout_due.connect(_play_source_boss_sendout)
    await source_boss.play_intro()
    if kind=="regigigas":await _play_source_boss_sendout()
    while not source_boss_sendout_finished:await get_tree().process_frame

func _play_source_boss_sendout() -> void:
    await _play_source_mewtwo_sendout(false)
    source_boss_sendout_finished=true

func _source_regigigas_damage() -> void:
    if not battle_active or int(battle_player.get("hp",0))<=0:return
    source_boss_damage_finished=false
    # Battle.java selects the impact cue using the preceding ordinary move's
    # type, but computes special damage using Ground. Preserve that distinction.
    var scale := BattleEngine.effectiveness(source_boss_move_type,battle_player.types)
    var cue := "SUPER_EFFECTIVE" if scale>1.0 else "NOT_VERY_EFFECTIVE" if scale>0.0 and scale<1.0 else "NEUTRAL_EFFECTIVE"
    await _play_source_battle_feedback(cue,false,{})
    if not battle_active:
        source_boss_damage_finished=true
        return
    var hp_before := int(battle_player.hp)
    var damage := int(30.0*BattleEngine.effectiveness("GROUND",battle_player.types))
    battle_player.hp=maxi(0,hp_before-damage)
    caught_pokemon[battle_party_index]=battle_player
    await _animate_visible_battle_hp(battle_player,hp_before,int(battle_player.hp))
    _update_battle_hud()
    source_boss_damage_finished=true

func _play_source_mewtwo_intro() -> void:
    battle_turn_busy = true
    _show_battle_intro_screen()
    enemy_sprite.visible = false
    player_battle_sprite.visible = false
    _start_battle_text("")
    var speech: Dictionary = preload("res://scripts/source_mewtwo_battle.gd").SPEECH
    if not source_mewtwo_intro_seen:
        var elapsed := 0.0
        var tick := 0
        while tick < 1708:
            await get_tree().process_frame
            elapsed += get_process_delta_time()
            var target := mini(1708, int(elapsed * 60.0))
            while tick < target:
                if speech.has(tick): _start_battle_text(String(speech[tick]))
                tick += 1
    else:
        world.environment_system.battle_music.seek(28.55)
    source_mewtwo_intro_seen = true
    _start_battle_text("")
    await _play_battle_transition(154)
    source_mewtwo = preload("res://scripts/source_mewtwo_battle.gd").new()
    battle_panel.add_child(source_mewtwo)
    battle_panel.move_child(source_mewtwo, 1)
    source_mewtwo.setup(self, bool(battle_enemy.get("shiny", false)))
    enemy_sprite.texture = source_mewtwo.body
    enemy_sprite.visible = true
    player_battle_sprite.visible = true
    await source_mewtwo.play_intro()

func _play_source_mewtwo_sendout(show_wild_intro: bool = true) -> void:
    if show_wild_intro:
        _play_pokemon_cry(battle_enemy)
        _show_battle_intro_screen()
    if not GameOptions.enabled("battle_animations"):
        _start_battle_text("Go! %s!" % PokemonState.display_name(battle_player))
        player_battle_sprite.visible = true
        battle_turn_busy = false
        _show_battle_command_screen()
        return
    await get_tree().create_timer(39.0/60.0).timeout
    var trainer_position := player_battle_sprite.position
    # MovePlayerOffScreen keeps the trainer still for 38 ticks, then steps out.
    var start_time := preload("res://scripts/game_clock.gd").ticks_usec()
    var deadlines := [38,40,43,46,49,52,55]
    var offsets := [0,-8,-16,-8,-16,-8,-16]
    var displacement := 0
    for step in range(deadlines.size()):
        while preload("res://scripts/game_clock.gd").ticks_usec()-start_time < int(deadlines[step]*1000000.0/60.0):
            await get_tree().process_frame
        displacement += int(offsets[step])
        player_battle_sprite.position = trainer_position+Vector2(displacement,0)
    player_battle_sprite.visible=false
    player_battle_sprite.position=trainer_position
    _start_battle_text("Go! %s!" % PokemonState.display_name(battle_player))
    var sendout := preload("res://scripts/source_pokemon_sendout.gd").new()
    battle_panel.add_child(sendout)
    sendout.position=player_battle_sprite.position
    sendout.size=player_battle_sprite.size
    sendout.z_index=player_battle_sprite.z_index
    sendout.setup(_battle_sprite_frame(PokemonData.record_texture(battle_player,"back")))
    await sendout.play(self)
    sendout.queue_free()
    if PokemonData.is_shiny(battle_player):
        player_battle_sprite.visible = true
        await _play_source_battle_feedback("SHINY", true, {})
    player_battle_sprite.visible=true
    battle_turn_busy=false
    _show_battle_command_screen()

func _play_battle_transition(source_frames: int = 28) -> void:
    if not GameOptions.enabled("battle_animations"):
        battle_transition.hide()
        battle_panel.show()
        return
    # PokeWilds 0.8.11 ships 28 authored 160x144 transition frames in this
    # sheet. Draw them over the live route, then reveal the prepared battle.
    battle_transition.visible = false
    battle_panel.visible = false
    var overlay := TextureRect.new()
    overlay.name = "SourceBattleTransition"
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    overlay.stretch_mode = TextureRect.STRETCH_SCALE
    overlay.position = Vector2.ZERO
    overlay.size = get_viewport().get_visible_rect().size
    overlay.z_index = 1000
    $UI.add_child(overlay)
    var transition_deadline := preload("res://scripts/game_clock.gd").ticks_usec()
    for tick in range(source_frames):
        var frame_index := mini(27, tick)
        var frame := AtlasTexture.new()
        frame.atlas = SOURCE_BATTLE_INTRO_TEXTURE
        frame.region = Rect2(float(frame_index * 160), 0.0, 160.0, 144.0)
        overlay.texture = frame
        transition_deadline += 16667
        while preload("res://scripts/game_clock.gd").ticks_usec() < transition_deadline:
            await get_tree().process_frame
    battle_panel.visible = true
    overlay.queue_free()

func _apply_pending_wild_record(enemy: Dictionary, level: int) -> Dictionary:
    if String(battle_context.get("kind", "wild")) == "wild" and world.has_method("take_pending_encounter_record"):
        var source_record: Dictionary = world.call("take_pending_encounter_record")
        if not source_record.is_empty():
            battle_context["overworld_record"] = source_record.duplicate(true)
        var source_properties = [
                "shiny", "is_shiny", "gender", "generation", "personality",
                "nature", "ability", "ability_slot", "ivs", "evs", "held_item",
                "friendship", "happiness", "nickname",
                "original_trainer", "trainer_id", "met_location",
                "pokeball", "ribbons", "markings", "pokerus"
            ]
        var wild_level_scaled = bool(
            battle_context.get("_wild_level_scaled", false)
        )
        if not wild_level_scaled:
            source_properties.append_array(["moves", "pp", "met_level"])
        for property in source_properties:
            if source_record.has(property):
                enemy[property] = source_record[property]
        if source_record.has("is_shiny") and not source_record.has("shiny"):
            enemy["shiny"] = bool(source_record["is_shiny"])
        if wild_level_scaled:
            enemy["level"] = level
            enemy["met_level"] = level
            enemy.erase("moves")
            enemy.erase("pp")
        enemy = BattleEngine.ensure_pokemon(enemy)
    return enemy

func _make_context_enemy(member: Dictionary) -> Dictionary:
    var species := String(member.get("species", "rattata")).to_lower()
    var level := maxi(1, int(member.get("level", 1)))
    var prepared := member.duplicate(true)
    prepared["original_trainer"] = String(prepared.get("original_trainer",
        battle_context.get("trainer_name", "WILD")))
    prepared["met_location"] = String(prepared.get("met_location",
        battle_context.get("id", "WILDERNESS")))
    var enemy := BattleEngine.make_pokemon(species, level, battle_rng, prepared)
    if bool(battle_context.get("requires_silph_scope", false)):
        enemy["is_ghost"] = not bool(battle_context.get("ghost_revealed", false))
    return enemy

func _trainer_battle_texture() -> Texture2D:
    player_model_index = clampi(
        player_model_index, 0, PLAYER_MODEL_BATTLE_BACK_TEXTURES.size() - 1
    )
    player_color_index = clampi(
        player_color_index, 0, PLAYER_COLOR_VALUES.size() - 1
    )
    return _recolor_texture(
        PLAYER_MODEL_BATTLE_BACK_TEXTURES[player_model_index],
        PLAYER_MODEL_BATTLE_REPLACE_COLORS[player_model_index],
        PLAYER_COLOR_VALUES[player_color_index],
        "battle_back:%d:%d" % [player_model_index, player_color_index]
    )

func _ghost_battle_texture() -> Texture2D:
    var atlas := AtlasTexture.new()
    atlas.atlas = GHOST_BATTLE_SHEET
    atlas.region = Rect2(0, 0, GHOST_BATTLE_SHEET.get_width(), GHOST_BATTLE_SHEET.get_width())
    return atlas

var battle_sprite_frame_counts: Dictionary = {}

## How many frames the sheet holds, stacked top to bottom.
func _battle_sprite_sheet_frames(texture: Texture2D) -> int:
    if texture == null:
        return 0
    var texture_width: int = texture.get_width()
    var texture_height: int = texture.get_height()
    if texture_width <= 0 or texture_height <= texture_width:
        return 1
    if texture_height % texture_width == 0:
        return maxi(1, int(texture_height / texture_width))
    return maxi(1, roundi(float(texture_height) / float(texture_width)))

## How many of those frames the idle animation steps through.
func _battle_sprite_frame_count(texture: Texture2D) -> int:
    var count := _battle_sprite_sheet_frames(texture)
    if count < 2:
        return count
    var texture_width: int = texture.get_width()
    var texture_height: int = texture.get_height()
    if texture_height % texture_width != 0:
        return count
    # An idle animation is the same pose with small changes. A sheet whose
    # second frame is a different drawing (Mega Gyarados) is not one: flipping
    # between the two makes the Pokemon thrash about. Show its first frame.
    var key := texture.resource_path if not texture.resource_path.is_empty() else str(texture.get_instance_id())
    if not battle_sprite_frame_counts.has(key):
        var image := texture.get_image()
        var different := 0
        if image != null and not image.is_empty():
            for y in range(texture_width):
                for x in range(texture_width):
                    if image.get_pixel(x, y) != image.get_pixel(x, y + texture_width):
                        different += 1
        # Real idle animations in the game change under two thirds of the frame.
        battle_sprite_frame_counts[key] = 1 if different * 10 > texture_width * texture_width * 7 else count
    return int(battle_sprite_frame_counts[key])

func _battle_sprite_frame_at(texture: Texture2D, animation_frame: int) -> Texture2D:
    if texture == null:
        return null
    # The sheet is always cut into its frames; a sheet that is not animated
    # stays on the first one instead of being drawn whole.
    var frame_count := _battle_sprite_sheet_frames(texture)
    var frame_index := posmod(animation_frame, maxi(1, _battle_sprite_frame_count(texture)))
    var cache_key := texture.resource_path
    if cache_key.is_empty():
        cache_key = str(texture.get_instance_id())
    cache_key += "#%d" % frame_index
    if battle_sprite_alpha_cache.has(cache_key):
        return battle_sprite_alpha_cache[cache_key] as Texture2D
    var texture_width: int = texture.get_width()
    var texture_height: int = texture.get_height()
    var result: Texture2D = texture
    if frame_count > 1 and texture_width > 0:
        var frame_height := texture_width if texture_height % texture_width == 0 else \
            ceili(float(texture_height) / float(frame_count))
        var frame_y := mini(frame_index * frame_height, maxi(0, texture_height - 1))
        var frame := AtlasTexture.new()
        frame.atlas = texture
        frame.region = Rect2(
            0, frame_y, texture_width,
            mini(frame_height, texture_height - frame_y)
        )
        result = frame
    result = _remove_connected_sprite_background(result)
    battle_sprite_alpha_cache[cache_key] = result
    return result

func _battle_sprite_frame(texture: Texture2D) -> Texture2D:
    return _battle_sprite_frame_at(texture, 0)

func _update_battle_sprite_animation(delta: float) -> void:
    if not GameOptions.enabled("battle_animations"):
        if battle_sprite_animation_frame != 0:
            battle_sprite_animation_frame = 0
            _refresh_battle_sprites()
        return
    if source_effect_playing:
        return
    if not battle_active or battle_panel == null or not battle_panel.visible:
        battle_sprite_animation_elapsed = 0.0
        battle_sprite_animation_frame = 0
        return
    # The INTRO intentionally holds the trainer back sprite. Refreshing the
    # Pokemon animation here swaps that texture mid-intro and causes flashing.
    if battle_ui_mode in ["INTRO", "TRANSITION"]:
        battle_sprite_animation_elapsed = 0.0
        battle_sprite_animation_frame = 0
        return
    battle_sprite_animation_elapsed += delta
    if battle_sprite_animation_elapsed < BATTLE_SPRITE_FRAME_SECONDS:
        return
    battle_sprite_animation_elapsed = fmod(
        battle_sprite_animation_elapsed, BATTLE_SPRITE_FRAME_SECONDS)
    battle_sprite_animation_frame += 1
    _refresh_battle_sprites()

func _remove_connected_sprite_background(texture: Texture2D) -> Texture2D:
    var image := texture.get_image()
    if image == null or image.is_empty():
        return texture
    image.convert(Image.FORMAT_RGBA8)
    var width := image.get_width()
    var height := image.get_height()
    # A sheet that already has a see-through background has nothing to remove.
    # White that reaches its edge is part of the Pokemon (Noivern's white ruff
    # on its back sprite), and erasing it left a hole that showed in dark mode.
    for corner in [Vector2i.ZERO, Vector2i(width - 1, 0), Vector2i(0, height - 1), Vector2i(width - 1, height - 1)]:
        if image.get_pixelv(corner).a < 0.01:
            return texture
    var pending: Array[Vector2i] = []
    for x in range(width):
        pending.append(Vector2i(x, 0))
        pending.append(Vector2i(x, height - 1))
    for y in range(height):
        pending.append(Vector2i(0, y))
        pending.append(Vector2i(width - 1, y))
    var visited: Dictionary = {}
    var removed := 0
    while not pending.is_empty():
        var cell: Vector2i = pending.pop_back()
        if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height or \
                visited.has(cell):
            continue
        visited[cell] = true
        var color := image.get_pixelv(cell)
        var lightest := maxf(color.r, maxf(color.g, color.b))
        var darkest := minf(color.r, minf(color.g, color.b))
        if color.a < 0.01 or darkest < 0.82 or lightest - darkest > 0.12:
            continue
        color.a = 0.0
        image.set_pixelv(cell, color)
        removed += 1
        pending.append(cell + Vector2i.LEFT)
        pending.append(cell + Vector2i.RIGHT)
        pending.append(cell + Vector2i.UP)
        pending.append(cell + Vector2i.DOWN)
    if removed <= 0:
        return texture
    return ImageTexture.create_from_image(image)

func _set_battle_message_width(full_width: bool) -> void:
    battle_status.offset_left = 16.0
    battle_status.offset_top = 135.0
    battle_status.offset_right = 300.0 if full_width else 125.0
    battle_status.offset_bottom = 175.0

func _restore_battle_background() -> void:
    if not is_instance_valid(battle_panel): return
    var backdrop: ColorRect = battle_panel.get_node("Background")
    backdrop.color = preload("res://scripts/dark_mode.gd").BACKGROUND if GameOptions.enabled("dark_mode") else Color.WHITE
    backdrop.show()

func _show_battle_intro_screen() -> void:
    _restore_battle_background()
    battle_ui_mode = "INTRO"
    source_command_frame.visible = false
    source_single_hud.visible = false
    source_command_cursor.visible = false
    enemy_hud.visible = false
    player_hud.visible = false
    battle_command_box.visible = true
    battle_command_divider.visible = false
    battle_actions.visible = false
    battle_actions.modulate = Color.WHITE
    battle_status.visible = true
    battle_move_type_box.visible = false
    battle_move_box.visible = false
    battle_message_arrow.visible = false
    _set_battle_message_width(true)
    player_battle_sprite.texture = _trainer_battle_texture()
    player_battle_sprite.visible = true
    enemy_sprite.visible = true
    player_battle_sprite.modulate = Color.WHITE
    enemy_sprite.modulate = Color.WHITE
    if bool(battle_context.get("pvp",false)):
        enemy_sprite.texture = preload("res://scripts/coop_trainer_portraits.gd").texture(self,battle_context.get("trainer_visual",{}))
    var intro = String(battle_context.get("intro", ""))
    if bool(battle_enemy.get("is_ghost", false)):
        intro = "Wild GHOST\nappeared!"
    elif intro.is_empty():
        intro = "Wild %s\nappeared!" % BattleEngine.display_name(battle_enemy)
    _start_battle_text(intro)

func _advance_battle_intro() -> void:
    if source_effect_playing: return
    var messages: Array = battle_context.get("_entry_messages", [])
    if not messages.is_empty():
        _start_battle_text(String(messages.pop_front()))
        battle_context["_entry_messages"] = messages
        return
    battle_context.erase("_entry_messages")
    if PokemonData.is_shiny(battle_player) and not battle_player_cry_played:
        _refresh_battle_sprites()
        await _play_source_battle_feedback("SHINY", true, {})
    _show_battle_command_screen()

func _show_battle_command_screen() -> void:
    if not battle_active or battle_player.is_empty() or battle_enemy.is_empty():
        return
    _restore_battle_background()
    battle_ui_mode = "COMMAND"
    var source_single := not battle_is_double
    # The authored top HUD remains source-accurate, but the command area uses
    # the project's dialogue border across the full viewport.
    source_command_frame.visible = false
    source_single_hud.visible = source_single
    source_command_cursor.visible = false
    enemy_hud.visible = not source_single
    player_hud.visible = not source_single
    battle_command_box.visible = true
    battle_command_divider.visible = true
    battle_actions.visible = true
    battle_actions.modulate = Color.WHITE
    battle_status.visible = true
    battle_move_type_box.visible = false
    battle_move_box.visible = false
    battle_message_arrow.visible = false
    _set_battle_message_width(false)
    _refresh_battle_sprites()
    if not battle_player_cry_played:
        battle_player_cry_played = true
        _play_pokemon_cry(battle_player)
    _update_battle_hud()
    _update_battle_command_cursor()
    var command_actor := _command_pokemon()
    _start_battle_text("What will\n%s do?" % PokemonState.display_name(command_actor))

func _command_pokemon() -> Dictionary:
    if battle_is_double and battle_double_command_slot == 1 and \
            not battle_player_partner.is_empty():
        return battle_player_partner
    return battle_player

func _show_battle_message_screen() -> void:
    battle_ui_mode = "MESSAGE"
    var source_single := not battle_is_double
    source_command_frame.visible = false
    source_single_hud.visible = source_single
    source_command_cursor.visible = false
    enemy_hud.visible = not source_single and not battle_enemy.is_empty()
    player_hud.visible = not source_single and not battle_player.is_empty()
    battle_command_box.visible = true
    battle_command_divider.visible = false
    battle_actions.visible = false
    battle_actions.modulate = Color.WHITE
    battle_status.visible = true
    battle_move_type_box.visible = false
    battle_move_box.visible = false
    battle_message_arrow.visible = false
    _set_battle_message_width(true)

func _open_battle_move_menu() -> void:
    var command_actor := _command_pokemon()
    if not battle_active or battle_turn_busy or command_actor.is_empty():
        return
    var forced := BattleEngine.forced_move(command_actor)
    if not forced.is_empty():
        _battle_fight()
        return
    var moves: Array = command_actor.get("moves", ["TACKLE"])
    if moves.is_empty():
        _battle_fight()
        return
    battle_move_index = clampi(battle_move_index, 0, mini(4, moves.size()) - 1)
    battle_ui_mode = "MOVE"
    var source_single := not battle_is_double
    source_command_frame.visible = false
    source_single_hud.visible = source_single
    source_command_cursor.visible = false
    enemy_hud.visible = not source_single
    player_hud.visible = not source_single
    battle_command_box.visible = false
    battle_actions.visible = false
    battle_actions.modulate = Color.WHITE
    battle_status.visible = false
    battle_message_arrow.visible = false
    battle_move_type_box.visible = true
    battle_move_box.visible = true
    _refresh_battle_move_menu()

func _handle_battle_move_input(event: InputEvent) -> void:
    if event.is_action_pressed("move_up") or event.is_action_pressed("move_left"):
        _move_battle_move(-1)
    elif event.is_action_pressed("move_down") or event.is_action_pressed("move_right"):
        _move_battle_move(1)
    elif event.is_action_pressed("shoulder_left"):
        _move_battle_move(-1)
    elif event.is_action_pressed("shoulder_right"):
        _move_battle_move(1)
    elif event.is_action_pressed("confirm"):
        _show_battle_message_screen()
        _battle_fight()
    elif event.is_action_pressed("cancel"):
        _show_battle_command_screen()
    else:
        return
    get_viewport().set_input_as_handled()

func _move_battle_move(direction: int) -> void:
    var moves: Array = _command_pokemon().get("moves", ["TACKLE"])
    var count := mini(4, moves.size())
    if count <= 0:
        return
    battle_move_index = wrapi(battle_move_index + direction, 0, count)
    _refresh_battle_move_menu()

func _refresh_battle_move_menu() -> void:
    var command_actor := _command_pokemon()
    var moves: Array = command_actor.get("moves", ["TACKLE"])
    var lines: Array[String] = []
    for index in range(4):
        if index < moves.size():
            lines.append(String(moves[index]).replace("_", " "))
        else:
            lines.append("-")
    battle_move_list.text = "\n".join(lines)
    battle_move_cursor.position.x = 12.0
    _align_menu_tick(battle_move_cursor, battle_move_list, battle_move_index)
    if moves.is_empty():
        battle_move_type.text = "NORMAL"
        battle_move_pp.text = "0/0"
        return
    var selected := String(moves[clampi(battle_move_index, 0, moves.size() - 1)])
    var move_data := PokemonData.move_info(selected)
    battle_move_type.text = String(move_data.get("type", "NORMAL"))
    var maximum_pp := int(move_data.get("pp", 0))
    var current_pp := int((command_actor.get("pp", {}) as Dictionary).get(selected, maximum_pp))
    battle_move_pp.text = "%d/%d" % [current_pp, maximum_pp]

func _move_battle_command(horizontal: int, vertical: int) -> void:
    if battle_turn_busy:
        return
    var column := battle_command_index % 2
    var row := int(battle_command_index / 2)
    if horizontal != 0:
        column = wrapi(column + horizontal, 0, 2)
    if vertical != 0:
        row = wrapi(row + vertical, 0, 2)
    battle_command_index = row * 2 + column
    _update_battle_command_cursor()

func _update_battle_command_cursor() -> void:
    if battle_command_cursor == null:
        return
    const CURSOR_POSITIONS = [
        Vector2(0, 1), Vector2(79, 1),
        Vector2(0, 24), Vector2(79, 24)
    ]
    battle_command_cursor.position = CURSOR_POSITIONS[battle_command_index]
    if battle_clean_command_cursor != null:
        var selected_button: Button = [fight_button, party_button,
            item_button, run_button][battle_command_index]
        var font_size: int = selected_button.get_theme_font_size("font_size")
        var command_width: float = JOHTO_FONT.get_string_size(
            selected_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
        var text_left: float = selected_button.position.x + (
            selected_button.size.x - command_width) * 0.5
        var gap: float = 2.0 if battle_command_index == 3 else 1.0
        battle_clean_command_cursor.position = Vector2(
            floorf(text_left - battle_clean_command_cursor.size.x - gap),
            roundf(selected_button.position.y +
                (selected_button.size.y - battle_clean_command_cursor.size.y) * 0.5 - 3.0)
        )
        battle_clean_command_cursor.visible = battle_actions.visible
    const SOURCE_CURSOR_POSITIONS = [
        Vector2(73, 112), Vector2(122, 112),
        Vector2(73, 128), Vector2(122, 128)
    ]
    source_command_cursor.position = SOURCE_CURSOR_POSITIONS[battle_command_index]

func _activate_battle_command() -> void:
    if battle_turn_busy:
        return
    if battle_is_double:
        match battle_command_index:
            0:
                _open_battle_move_menu()
            1:
                battle_double_replacement_slot = battle_double_command_slot
                _open_battle_party_menu("DOUBLE_SWITCH")
            2:
                _open_battle_item_menu()
            3:
                _start_battle_text("There is no running from this double battle!")
        return
    match battle_command_index:
        0:
            _open_battle_move_menu()
        1:
            _open_battle_party_menu("PARTY")
        2:
            _open_battle_item_menu()
        3:
            _battle_run()

func _cycle_battle_move(direction: int) -> void:
    var command_actor := _command_pokemon()
    if battle_turn_busy or command_actor.is_empty():
        return
    var forced := BattleEngine.forced_move(command_actor)
    if not forced.is_empty():
        _start_battle_text("%s is locked into %s." % [
            PokemonState.display_name(battle_player), forced.replace("_", " ")])
        return
    var moves: Array = command_actor.get("moves", ["TACKLE"])
    if moves.is_empty():
        return
    for attempt in range(moves.size()):
        battle_move_index = wrapi(battle_move_index + direction, 0, moves.size())
        if BattleEngine.move_is_usable(command_actor, String(moves[battle_move_index])):
            break
    var selected := String(moves[battle_move_index]).replace("_", " ")
    var pp_left := int((battle_player.get("pp", {}) as Dictionary).get(moves[battle_move_index], 0))
    _start_battle_text("%s  PP %d" % [selected, pp_left])

func _first_healthy_party_index() -> int:
    for index in range(caught_pokemon.size()):
        if (
                typeof(caught_pokemon[index]) == TYPE_DICTIONARY
                and bool((caught_pokemon[index] as Dictionary).get("is_egg", false))
            ):
            continue
        var candidate := BattleEngine.ensure_pokemon(caught_pokemon[index])
        caught_pokemon[index] = candidate
        if int(candidate.hp) > 0:
            return index
    return -1

func _battle_fight() -> void:
    if is_instance_valid(coop_game.pvp) and coop_game.pvp.active:
        if not battle_turn_busy:coop_game.pvp.submit({"kind":"move","move":_selected_player_move()})
        return
    if not battle_active or battle_turn_busy:
        return
    if battle_is_double:
        _queue_double_player_move()
        return
    battle_turn_busy = true
    _show_battle_message_screen()
    var player_move := _selected_player_move()
    var enemy_action := _choose_enemy_action()
    if String(enemy_action.get("kind", "move")) != "move":
        await _perform_enemy_tactical_action(enemy_action)
        if not battle_active:
            return
        await _perform_battle_action(true, player_move)
        if await _resolve_battle_faints():
            return
        await _apply_battle_end_turn()
        if await _resolve_battle_faints():
            return
        battle_turn_busy = false
        _show_battle_command_screen()
        return
    var enemy_move := String(enemy_action.get("move", _first_usable_move(battle_enemy)))
    var player_first := BattleEngine.player_moves_first(
        battle_player, player_move, battle_enemy, enemy_move, battle_rng, battle_field)
    if player_first:
        await _perform_battle_action(true, player_move)
        if not battle_active:
            return
        if await _resolve_battle_faints():
            return
        await _perform_battle_action(false, enemy_move)
        if not battle_active:
            return
        if await _resolve_battle_faints():
            return
    else:
        await _perform_battle_action(false, enemy_move)
        if not battle_active:
            return
        if await _resolve_battle_faints():
            return
        await _perform_battle_action(true, player_move)
        if not battle_active:
            return
        if await _resolve_battle_faints():
            return
    await _apply_battle_end_turn()
    if await _resolve_battle_faints():
        return
    battle_turn_busy = false
    _show_battle_command_screen()

func _queue_double_player_move() -> void:
    var actor := _command_pokemon()
    if actor.is_empty() or int(actor.get("hp", 0)) <= 0:
        _advance_double_command_slot()
        return
    var move_name := _selected_player_move()
    if BattleEngine.move_targets_self(move_name):
        _store_double_player_action(move_name, battle_double_command_slot, "player")
        return
    if BattleEngine.move_targets_all(move_name):
        _store_double_player_action(move_name, -1)
        return
    battle_double_pending_move = move_name
    battle_submenu_mode = "DOUBLE_TARGET"
    battle_submenu_index = 0
    battle_submenu_entries.clear()
    for slot in range(2):
        var target := _double_actor("enemy", slot)
        if not target.is_empty() and int(target.get("hp", 0)) > 0:
            battle_submenu_entries.append({"target_slot":slot, "pokemon":target})
    if battle_submenu_entries.is_empty():
        _store_double_player_action(move_name, -1)
        return
    battle_submenu.visible = true
    _refresh_battle_submenu()

func _store_double_player_action(move_name: String, target_slot: int,
        target_side: String = "enemy") -> void:
    _close_battle_submenu()
    battle_double_actions.append({
        "side":"player", "slot":battle_double_command_slot,
        "move":move_name, "target_slot":target_slot,
        "target_side":target_side,
        "spread":BattleEngine.move_targets_all(move_name)
    })
    battle_double_pending_move = ""
    _advance_double_command_slot()

func _advance_double_command_slot() -> void:
    if battle_double_command_slot == 0 and not battle_player_partner.is_empty() and \
            int(battle_player_partner.get("hp", 0)) > 0:
        battle_double_command_slot = 1
        battle_move_index = 0
        _show_battle_command_screen()
        return
    battle_turn_busy = true
    _show_battle_message_screen()
    await _resolve_double_turn()

func _double_actor(side: String, slot: int) -> Dictionary:
    if side == "player":
        return battle_player if slot == 0 else battle_player_partner
    return battle_enemy if slot == 0 else battle_enemy_partner

func _living_double_entries(side: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for slot in range(2):
        var pokemon := _double_actor(side, slot)
        if not pokemon.is_empty() and int(pokemon.get("hp", 0)) > 0:
            result.append({"slot":slot, "pokemon":pokemon})
    return result

func _resolve_double_turn() -> void:
    var actions: Array[Dictionary] = battle_double_actions.duplicate(true)
    var player_entries := _living_double_entries("player")
    var player_targets: Array = []
    for entry in player_entries: player_targets.append(entry.pokemon)
    var enemy_entries := _living_double_entries("enemy")
    var enemy_targets: Array = []
    for entry in enemy_entries: enemy_targets.append(entry.pokemon)
    var reserved_switches: Array[int] = []
    var double_heal_available := String(battle_context.get("kind", "")) == "trainer" and \
        int(battle_context.get("_trainer_heals_used", 0)) < int(
            battle_context.get("trainer_heals", 1))
    for enemy_entry in enemy_entries:
        var actor := enemy_entry.pokemon as Dictionary
        var choice := BattleEngine.choose_ai_action(actor, player_targets,
            enemy_targets, battle_field, battle_rng,
            int(battle_context.get("ai_level", 2)))
        if double_heal_available and int(actor.hp) * 3 <= int(actor.max_hp):
            actions.append({
                "kind":"enemy_item", "side":"enemy", "slot":int(enemy_entry.slot),
                "move":"", "target_slot":int(enemy_entry.slot), "spread":false
            })
            double_heal_available = false
            continue
        if String(battle_context.get("kind", "")) == "trainer" and \
                float(choice.get("score", 0.0)) < 18.0:
            _prepare_enemy_party_records()
            var excluded := [battle_enemy_party_index, battle_enemy_partner_party_index]
            excluded.append_array(reserved_switches)
            var switch_index := BattleEngine.best_switch_index(battle_enemy_party,
                excluded, battle_player, battle_field)
            if switch_index >= 0:
                reserved_switches.append(switch_index)
                actions.append({
                    "kind":"enemy_switch", "side":"enemy", "slot":int(enemy_entry.slot),
                    "switch_index":switch_index, "move":"", "target_slot":-1,
                    "spread":false
                })
                continue
        var target_slot := 0
        var target_pick := clampi(int(choice.get("target", 0)), 0,
            maxi(0, player_entries.size() - 1))
        if not player_entries.is_empty():
            target_slot = int(player_entries[target_pick].slot)
        actions.append({
            "side":"enemy", "slot":int(enemy_entry.slot),
            "move":String(choice.get("move", "STRUGGLE")),
            "target_slot":target_slot, "spread":bool(choice.get("spread", false))
        })
        if BattleEngine.move_targets_self(String(choice.get("move", "STRUGGLE"))):
            actions[-1]["target_side"] = "enemy"
    for action in actions:
        var actor := _double_actor(String(action.side), int(action.slot))
        action["priority"] = 6 if String(action.get("kind", "move")) in [
            "switch", "enemy_switch", "enemy_item"] else \
            BattleEngine.pokemon_move_priority(actor, String(action.get("move", "")))
        action["speed"] = BattleEngine.effective_stat(actor, "speed", battle_field)
        action["tie"] = battle_rng.randf()
    actions.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
        if int(first.priority) != int(second.priority):
            return int(first.priority) > int(second.priority)
        if int(first.speed) != int(second.speed):
            return int(first.speed) > int(second.speed)
        return float(first.tie) < float(second.tie)
    )
    for action in actions:
        if not battle_active:
            return
        var attacker := _double_actor(String(action.side), int(action.slot))
        if attacker.is_empty() or int(attacker.get("hp", 0)) <= 0:
            continue
        if String(action.get("kind", "move")) == "switch":
            await _execute_double_player_switch(int(action.slot), int(action.switch_index))
            continue
        if String(action.get("kind", "move")) == "enemy_switch":
            await _execute_double_enemy_switch(int(action.slot), int(action.switch_index))
            continue
        if String(action.get("kind", "move")) == "enemy_item":
            await _execute_double_enemy_item(int(action.slot))
            continue
        await _perform_double_move(action)
    if not battle_active:
        return
    await _apply_double_end_turn()
    if await _resolve_double_faints():
        return
    battle_double_actions.clear()
    battle_double_command_slot = 0 if int(battle_player.get("hp", 0)) > 0 else 1
    battle_move_index = 0
    battle_turn_busy = false
    _show_battle_command_screen()

func _perform_double_move(action: Dictionary) -> void:
    var side = String(action.side)
    var attacker = _double_actor(side, int(action.slot))
    var move_name = String(action.move)
    var repeated_without_pp = not String(attacker.volatile.get("charge_move", "")).is_empty() or \
        int(attacker.volatile.get("bide_turns", 0)) > 0 or \
        int(attacker.volatile.get("locked_turns", 0)) > 0
    if move_name != "STRUGGLE" and not repeated_without_pp:
        attacker.pp[move_name] = maxi(0, int(attacker.pp.get(move_name, 1)) - 1)
    var opposing_side = "enemy" if side == "player" else "player"
    var targets: Array[Dictionary] = []
    if bool(action.get("spread", false)):
        for slot in range(2):
            var spread_target = _double_actor(opposing_side, slot)
            if not spread_target.is_empty() and int(spread_target.get("hp", 0)) > 0:
                targets.append({"side":opposing_side, "slot":slot})
        if BattleEngine.move_hits_all_adjacent(move_name):
            var ally_slot = 1 - int(action.slot)
            var ally_target = _double_actor(side, ally_slot)
            if not ally_target.is_empty() and int(ally_target.get("hp", 0)) > 0:
                targets.append({"side":side, "slot":ally_slot})
    else:
        var requested_slot = int(action.get("target_slot", 0))
        var requested_side = String(action.get("target_side", opposing_side))
        var requested = _double_actor(requested_side, requested_slot)
        if not requested.is_empty() and int(requested.get("hp", 0)) > 0:
            targets.append({"side":requested_side, "slot":requested_slot})
        else:
            var living = _living_double_entries(opposing_side)
            if not living.is_empty(): targets.append({"side":opposing_side,
                "slot":int(living[0].slot)})
    if targets.is_empty():
        return
    var first_result: Dictionary = {}
    var self_fainting_spread = "SELFDESTRUCT" in String(
        PokemonData.move_info(move_name).get("effect", ""))
    for target_index in range(targets.size()):
        if int(attacker.get("hp", 0)) <= 0 and not self_fainting_spread:
            break
        var target_spec: Dictionary = targets[target_index]
        var defender = _double_actor(String(target_spec.side), int(target_spec.slot))
        var attacker_hp_before = int(attacker.get("hp", 0))
        var defender_hp_before = int(defender.get("hp", 0))
        var defender_status_before := _battle_status_snapshot(defender)
        battle_field.attacker_is_player = side == "player"
        battle_field.attacker_slot = int(action.slot)
        if bool(action.get("spread", false)):
            battle_field["spread_modifier"] = 0.75
        if target_index > 0:
            if not bool(first_result.get("executed", false)):
                break
            battle_field["skip_can_act"] = true
        var result = BattleEngine.use_move(attacker, defender, move_name,
            battle_rng, battle_field)
        var action_log: Array = battle_field.get("action_log", [])
        action_log.append(String(result.get("message", "")))
        if action_log.size() > 40:
            action_log.pop_front()
        battle_field["action_log"] = action_log
        if target_index == 0: first_result = result
        battle_field.erase("skip_can_act")
        battle_field.erase("attacker_slot")
        battle_field.erase("spread_modifier")
        if not String(result.get("weather", "")).is_empty():
            battle_field.weather = String(result.weather)
            battle_field.weather_turns = 5
        if bool(result.get("heal_party", false)) and side == "player":
            for party_index in range(caught_pokemon.size()):
                if typeof(caught_pokemon[party_index]) == TYPE_DICTIONARY:
                    caught_pokemon[party_index]["status"] = ""
        if int(result.get("pay_day", 0)) > 0:
            inventory["COINS"] = int(inventory.get("COINS", 0)) + int(result.pay_day)
        var message_parts = _battle_message_parts(String(result.message))
        _start_battle_text("Target %s: %s" % [
            BattleEngine.display_name(defender),
            message_parts[0]])
        if battle_text_busy:
            await battle_text_finished
        if not bool(result.get("executed", false)):
            await _play_blocked_status_feedback(attacker, side == "player", String(result.get("message", "")))
        else:
            await _play_battle_feedback(String(result.get("animation_move", move_name)),
                side == "player", result, defender)
        if battle_text_busy:
            await battle_text_finished
        _sync_double_records()
        _refresh_battle_sprites()
        await _animate_visible_battle_hp(defender, int(defender.hp) if bool(result.get("hp_feedback_complete", false)) else defender_hp_before,
            int(defender.get("hp", 0)))
        if int(defender.hp) != defender_hp_before:
            await get_tree().create_timer(13.0 / 60.0).timeout
        await _animate_visible_battle_hp(attacker, attacker_hp_before,
            int(attacker.get("hp", 0)))
        if int(attacker.hp) != attacker_hp_before:
            await get_tree().create_timer(13.0 / 60.0).timeout
        _update_battle_hud()
        if not message_parts[1].is_empty():
            await _type_battle_text(message_parts[1])
        await _play_new_status_feedback(defender, String(target_spec.side) == "player",
            defender_status_before, result)
        await get_tree().create_timer(0.08).timeout
    if int(attacker.get("hp", 0)) > 0:
        await _apply_after_action_residual_feedback(attacker, side == "player")

func _sync_double_records() -> void:
    if battle_party_index >= 0 and battle_party_index < caught_pokemon.size():
        caught_pokemon[battle_party_index] = battle_player
    if battle_partner_party_index >= 0 and battle_partner_party_index < caught_pokemon.size():
        caught_pokemon[battle_partner_party_index] = battle_player_partner
    if battle_enemy_party_index >= 0 and battle_enemy_party_index < battle_enemy_party.size():
        battle_enemy_party[battle_enemy_party_index] = battle_enemy
    if battle_enemy_partner_party_index >= 0 and \
            battle_enemy_partner_party_index < battle_enemy_party.size():
        battle_enemy_party[battle_enemy_partner_party_index] = battle_enemy_partner

func _apply_double_end_turn() -> void:
    battle_turn_count += 1
    battle_field["turn_count"] = battle_turn_count
    var messages: Array[String] = []
    for side in ["player", "enemy"]:
        for entry in _living_double_entries(side):
            var hp_before := int(entry.pokemon.get("hp",0))
            var poisoned_before := String(entry.pokemon.get("status",""))=="POISON" and not bool(entry.pokemon.volatile.get("action_residual_applied", false))
            var trap_side := "player" if bool(entry.pokemon.volatile.get("trap_source_player", side != "player")) else "enemy"
            var trap_source := _double_actor(trap_side, int(entry.pokemon.volatile.get("trap_source_slot", 0)))
            var message := BattleEngine.end_turn(entry.pokemon, battle_field, trap_source, battle_rng)
            await _play_poison_status_feedback(entry.pokemon,side=="player",hp_before,poisoned_before)
            if not message.is_empty(): messages.append(message)
    if int(battle_field.get("weather_turns", 0)) > 0:
        battle_field.weather_turns = int(battle_field.weather_turns) - 1
        if int(battle_field.weather_turns) <= 0:
            var old_weather := String(battle_field.get("weather", ""))
            battle_field.weather = ""
            messages.append("The %s subsided." % old_weather.replace("_", " ").to_lower())
    _sync_double_records()
    _update_battle_field_visuals()
    if not messages.is_empty():
        await _type_battle_text(" ".join(messages))
        await get_tree().create_timer(0.1).timeout

func _resolve_double_faints() -> bool:
    var faint_messages: Array[String] = []
    var progression_rewards: Array[Dictionary] = []
    for slot in range(2):
        var defeated := _double_actor("enemy", slot)
        if defeated.is_empty() or int(defeated.get("hp", 0)) > 0 or \
                bool(defeated.get("_double_faint_processed", false)):
            continue
        defeated["_double_faint_processed"] = true
        faint_messages.append("%s fainted!" % BattleEngine.display_name(defeated))
        _sync_double_records()
        var recipients := BattleEngine.experience_recipients(caught_pokemon,
            battle_exp_participants, battle_party_index)
        var reward := BattleEngine.experience_reward(defeated, recipients.size())
        for index in recipients:
            var recipient: Dictionary = caught_pokemon[index]
            PokemonState.grant_evs(recipient, defeated)
            progression_rewards.append({
                "pokemon": recipient,
                "party_index": index,
                "reward": reward
            })
        faint_messages.append("Participating Pokemon gained %d EXP." % reward)
    if not faint_messages.is_empty():
        _sync_double_records()
        _update_battle_hud()
        await _type_battle_text(" ".join(faint_messages))
        await get_tree().create_timer(0.125).timeout
        for progression_reward in progression_rewards:
            await _run_experience_progression(
                progression_reward.pokemon,
                int(progression_reward.reward),
                int(progression_reward.party_index))
        _sync_double_records()
        _refresh_battle_sprites()
        _update_battle_hud()
    for slot in range(2):
        var defeated := _double_actor("enemy", slot)
        if defeated.is_empty() or int(defeated.get("hp", 0)) > 0:
            continue
        var replacement_index := _next_double_enemy_bench_index()
        if replacement_index >= 0:
            await _replace_double_enemy(slot, replacement_index)
    if _living_double_entries("enemy").is_empty():
        _end_battle("victory" if String(battle_context.get("kind", "")) == "trainer" else "defeated")
        return true
    var player_faints: Array[String] = []
    for slot in range(2):
        var fallen := _double_actor("player", slot)
        if fallen.is_empty() or int(fallen.get("hp", 0)) > 0 or \
                bool(fallen.get("_double_faint_announced", false)):
            continue
        fallen["_double_faint_announced"] = true
        player_faints.append("%s fainted!" % PokemonState.display_name(fallen))
    if not player_faints.is_empty():
        await _type_battle_text(" ".join(player_faints))
        await get_tree().create_timer(0.1).timeout
    for slot in range(2):
        var defeated_player := _double_actor("player", slot)
        if defeated_player.is_empty() or int(defeated_player.get("hp", 0)) > 0:
            continue
        var available := _healthy_double_player_bench_indices()
        if available.is_empty():
            continue
        battle_double_replacement_slot = slot
        _open_battle_party_menu("DOUBLE_FORCED")
        var next_index = await battle_party_chosen
        await _replace_double_player(slot, int(next_index))
    if _living_double_entries("player").is_empty():
        await _type_battle_text("You are out of usable Pokemon.")
        await get_tree().create_timer(0.125).timeout
        _end_battle("whiteout")
        return true
    _refresh_battle_sprites()
    _update_battle_hud()
    return false

func _next_double_enemy_bench_index() -> int:
    _prepare_enemy_party_records()
    for index in range(battle_enemy_party.size()):
        if index in [battle_enemy_party_index, battle_enemy_partner_party_index]:
            continue
        var record := battle_enemy_party[index] as Dictionary
        if int(record.get("hp", 0)) > 0:
            return index
    return -1

func _healthy_double_player_bench_indices() -> Array[int]:
    var result: Array[int] = []
    for index in range(caught_pokemon.size()):
        if index in [battle_party_index, battle_partner_party_index] or \
                typeof(caught_pokemon[index]) != TYPE_DICTIONARY:
            continue
        var pokemon := BattleEngine.ensure_pokemon(caught_pokemon[index])
        caught_pokemon[index] = pokemon
        if int(pokemon.hp) > 0 and not bool(pokemon.get("is_egg", false)):
            result.append(index)
    return result

func _replace_double_enemy(slot: int, next_index: int) -> void:
    var next_record := battle_enemy_party[next_index] as Dictionary
    var replacement := BattleEngine.ensure_pokemon(next_record)
    BattleEngine.reset_battle_state(replacement)
    replacement.erase("_double_faint_processed")
    var enemy_spikes := int(battle_field.get("enemy_spikes", 0))
    if enemy_spikes > 0 and not (replacement.types as Array).has("FLYING") and \
            String(replacement.get("ability", "")) != "LEVITATE":
        replacement.hp = maxi(0, int(replacement.hp) -
            maxi(1, int(int(replacement.max_hp) * enemy_spikes / 8.0)))
    if slot == 0:
        battle_enemy_party_index = next_index
        battle_enemy = replacement
        current_species = String(replacement.species)
        current_level = int(replacement.level)
    else:
        battle_enemy_partner_party_index = next_index
        battle_enemy_partner = replacement
    battle_enemy_party[next_index] = replacement
    _refresh_battle_sprites()
    _play_pokemon_cry(replacement)
    var entry := BattleEngine.switch_in_message(replacement,
        _living_double_entries("player").map(func(value): return value.pokemon), battle_field)
    var message := "%s sent out %s!" % [String(battle_context.get(
        "trainer_name", "The opponent")), BattleEngine.display_name(replacement)]
    if not entry.is_empty(): message += " " + entry
    await _type_battle_text(message)
    await get_tree().create_timer(0.1).timeout

func _replace_double_player(slot: int, next_index: int) -> void:
    if not battle_exp_participants.has(next_index): battle_exp_participants.append(next_index)
    var replacement := BattleEngine.ensure_pokemon(caught_pokemon[next_index])
    BattleEngine.reset_battle_state(replacement)
    var player_spikes := int(battle_field.get("player_spikes", 0))
    if player_spikes > 0 and not (replacement.types as Array).has("FLYING") and \
            String(replacement.get("ability", "")) != "LEVITATE":
        replacement.hp = maxi(0, int(replacement.hp) -
            maxi(1, int(int(replacement.max_hp) * player_spikes / 8.0)))
    if slot == 0:
        battle_party_index = next_index
        battle_player = replacement
    else:
        battle_partner_party_index = next_index
        battle_player_partner = replacement
    caught_pokemon[next_index] = replacement
    _refresh_battle_sprites()
    _play_pokemon_cry(replacement)
    var entry := BattleEngine.switch_in_message(replacement,
        _living_double_entries("enemy").map(func(value): return value.pokemon), battle_field)
    var message := "Go, %s!" % BattleEngine.display_name(replacement)
    if not entry.is_empty(): message += " " + entry
    await _type_battle_text(message)
    await get_tree().create_timer(0.1).timeout

func _execute_double_player_switch(slot: int, next_index: int) -> void:
    var outgoing := _double_actor("player", slot)
    var outgoing_index := battle_party_index if slot == 0 else battle_partner_party_index
    var out_message := BattleEngine.switch_out_message(outgoing)
    BattleEngine.reset_battle_state(outgoing)
    if outgoing_index >= 0 and outgoing_index < caught_pokemon.size():
        caught_pokemon[outgoing_index] = outgoing
    await _replace_double_player(slot, next_index)
    if not out_message.is_empty():
        await _type_battle_text(out_message)
        await get_tree().create_timer(0.075).timeout

func _execute_double_enemy_switch(slot: int, next_index: int) -> void:
    var outgoing := _double_actor("enemy", slot)
    var outgoing_index := battle_enemy_party_index if slot == 0 else \
        battle_enemy_partner_party_index
    var out_message := BattleEngine.switch_out_message(outgoing)
    BattleEngine.reset_battle_state(outgoing)
    if outgoing_index >= 0 and outgoing_index < battle_enemy_party.size():
        battle_enemy_party[outgoing_index] = outgoing
    await _replace_double_enemy(slot, next_index)
    if not out_message.is_empty():
        await _type_battle_text(out_message)
        await get_tree().create_timer(0.075).timeout

func _execute_double_enemy_item(slot: int) -> void:
    var target := _double_actor("enemy", slot)
    var restored := mini(50, int(target.max_hp) - int(target.hp))
    target.hp = int(target.hp) + restored
    battle_context["_trainer_heals_used"] = int(
        battle_context.get("_trainer_heals_used", 0)) + 1
    await _type_battle_text("%s used a SUPER POTION on %s. Restored %d HP!" % [
        String(battle_context.get("trainer_name", "The Trainer")),
        BattleEngine.display_name(target), restored])
    await get_tree().create_timer(0.09).timeout

func _perform_battle_action(player_attacks: bool, move_name: String) -> Dictionary:
    if not player_attacks:
        battle_enemy_action_count += 1
        var special_every = int(battle_context.get("special_every", 0))
        if String(battle_context.get("source_boss", "")).is_empty() and not bool(battle_context.get("source_mewtwo", false)) and special_every > 0 and battle_enemy_action_count % special_every == 0:
            var special_move = String(battle_context.get("special_move", "")).to_upper()
            if not special_move.is_empty() and not PokemonData.move_info(special_move).is_empty():
                move_name = special_move
                battle_field["move_power_override"] = int(battle_context.get("special_power", 0))
                var special_pp = battle_enemy.get("pp", {}) as Dictionary
                if not special_pp.has(special_move):
                    special_pp[special_move] = int(PokemonData.move_info(special_move).get("pp", 35))
                    battle_enemy["pp"] = special_pp
                var special_message = String(battle_context.get("special_message", ""))
                if not special_message.is_empty():
                    await _type_battle_text(special_message)
                    await get_tree().create_timer(0.1).timeout
    var attacker = battle_player if player_attacks else battle_enemy
    var defender = battle_enemy if player_attacks else battle_player
    var attacker_hp_before = int(attacker.get("hp", 0))
    var defender_hp_before = int(defender.get("hp", 0))
    var defender_status_before := _battle_status_snapshot(defender)
    var raid_enemy_hp_before=int(battle_enemy.hp)
    var repeated_without_pp = not String(attacker.volatile.get("charge_move", "")).is_empty() or \
        int(attacker.volatile.get("bide_turns", 0)) > 0 or \
        int(attacker.volatile.get("locked_turns", 0)) > 0
    if move_name != "STRUGGLE" and not repeated_without_pp:
        var pp: Dictionary = attacker.get("pp", {})
        pp[move_name] = maxi(0, int(pp.get(move_name, 1)) - 1)
        attacker.pp = pp
    battle_field.attacker_is_player = player_attacks
    var result = BattleEngine.use_move(attacker, defender, move_name, battle_rng, battle_field)
    if coop_game.active and coop_game.raids.active:await coop_game.raids.sync_damage(raid_enemy_hp_before)
    battle_field.erase("move_power_override")
    if not String(result.get("weather", "")).is_empty():
        battle_field.weather = String(result.weather)
        battle_field.weather_turns = 5
        _update_battle_field_visuals()
    if bool(result.get("heal_party", false)):
        for index in range(caught_pokemon.size()):
            if typeof(caught_pokemon[index]) == TYPE_DICTIONARY:
                caught_pokemon[index]["status"] = ""
                caught_pokemon[index]["status_counter"] = 0
                caught_pokemon[index]["toxic_counter"] = 0
        battle_player.status = ""
    if int(result.get("pay_day", 0)) > 0:
        inventory["COINS"] = int(inventory.get("COINS", 0)) + int(result.pay_day)
    caught_pokemon[battle_party_index] = battle_player
    var message_parts = _battle_message_parts(String(result.message))
    _start_battle_text(message_parts[0])
    if battle_text_busy:
        await battle_text_finished
    if not bool(result.get("executed", false)):
        await _play_blocked_status_feedback(attacker, player_attacks, String(result.get("message", "")))
    else:
        await _play_battle_feedback(String(result.get("animation_move", move_name)),
            player_attacks, result, defender)
    if battle_text_busy:
        await battle_text_finished
    _refresh_battle_sprites()
    await _animate_visible_battle_hp(defender, int(defender.hp) if bool(result.get("hp_feedback_complete", false)) else defender_hp_before,
        int(defender.get("hp", 0)))
    if int(defender.hp) != defender_hp_before:
        await get_tree().create_timer(13.0 / 60.0).timeout
    await _animate_visible_battle_hp(attacker, attacker_hp_before,
        int(attacker.get("hp", 0)))
    if int(attacker.hp) != attacker_hp_before:
        await get_tree().create_timer(13.0 / 60.0).timeout
    _update_battle_hud()
    if not message_parts[1].is_empty():
        await _type_battle_text(message_parts[1])
    await _play_new_status_feedback(defender, not player_attacks, defender_status_before, result)
    await get_tree().create_timer(0.1).timeout
    var switch_effect = String(result.get("force_switch", ""))
    if switch_effect == "BATON_PASS" and player_attacks:
        await _request_baton_pass()
    elif switch_effect == "FORCE_SWITCH":
        if player_attacks:
            await _type_battle_text("%s was blown away!" % BattleEngine.display_name(battle_enemy))
            await get_tree().create_timer(0.1).timeout
            _end_battle("victory" if String(battle_context.get("kind", "")) == "trainer" else "defeated")
        else:
            await _request_forced_player_switch()
    elif switch_effect == "TELEPORT":
        await _type_battle_text("%s teleported away!" % BattleEngine.display_name(attacker))
        await get_tree().create_timer(0.1).timeout
        _end_battle("ran")
    if not player_attacks and is_instance_valid(source_mewtwo) and battle_active and \
            battle_enemy_action_count % 3 == 0 and int(battle_enemy.hp) > 0 and int(battle_player.hp) > 0:
        await get_tree().create_timer(3.0 / 60.0).timeout
        await _type_battle_text("A wave of psychic power unleashes!")
        await source_mewtwo.play_special()
        var hp_before := int(battle_player.hp)
        var damage := int(30.0 * BattleEngine.effectiveness("PSYCHIC", battle_player.types))
        battle_player.hp = maxi(0, hp_before - damage)
        caught_pokemon[battle_party_index] = battle_player
        await _animate_visible_battle_hp(battle_player, hp_before, int(battle_player.hp))
        _update_battle_hud()
        await get_tree().create_timer(30.0 / 60.0).timeout
    if not player_attacks and is_instance_valid(source_boss) and source_boss.kind=="regigigas" and battle_active and move_name not in ["AURORA_BEAM","CLAMP","SUPERSONIC","WITHDRAW","STRUGGLE","PSYCHIC","NIGHT_SHADE","SLASH","SHADOW_CLAW","LICK"]:
        source_boss_action_count+=1
        if source_boss_action_count>=3 and int(battle_enemy.hp)>0 and int(battle_player.hp)>0:
            source_boss_action_count=0
            await get_tree().create_timer(3.0/60.0).timeout
            await _type_battle_text("The ground is shaking violently!")
            source_boss_move_type=String(PokemonData.move_info(move_name).get("type","NORMAL"))
            await source_boss.play_special()
            while not source_boss_damage_finished:await get_tree().process_frame
            if is_instance_valid(source_boss):source_boss.set_palette_stage(0)
            await get_tree().create_timer(30.0/60.0).timeout
    if battle_active and int(attacker.get("hp", 0)) > 0 and int(defender.get("hp", 0)) > 0:
        await _apply_after_action_residual_feedback(attacker, player_attacks)
    return result

func _apply_after_action_residual_feedback(pokemon: Dictionary, player_side: bool) -> void:
    var hp_before := int(pokemon.get("hp", 0))
    var was_poisoned := String(pokemon.get("status", "")) == "POISON"
    var message := BattleEngine.after_action_residual(pokemon)
    if not player_side and coop_game.active and coop_game.raids.active:await coop_game.raids.sync_damage(hp_before)
    if message.is_empty(): return
    await _type_battle_text(message)
    await _play_poison_status_feedback(pokemon, player_side, hp_before, was_poisoned)
    await _animate_visible_battle_hp(pokemon, hp_before, int(pokemon.hp))
    _update_battle_hud()
    await get_tree().create_timer(13.0 / 60.0).timeout

func _resolve_battle_faints() -> bool:
    if int(battle_enemy.hp) <= 0:
        await _finish_enemy_faint()
        return true
    if int(battle_player.hp) <= 0:
        return await _handle_player_faint()
    return false

var battle_exp_participants: Array[int] = []

func _check_reward_evolution(pokemon: Dictionary, party_index: int) -> void:
    var target := BattleEngine.evolution_target(pokemon, caught_pokemon, _world_source_time_of_day())
    if not target.is_empty():
        var was_active := progression_active
        var previous_actor := battle_player
        progression_active = true
        battle_player = pokemon
        await _run_evolution_sequence(pokemon, target, party_index)
        battle_player = previous_actor
        progression_active = was_active
        progression_mode = ""
        _refresh_battle_sprites()
        _update_battle_hud()

func _award_source_experience(defeated: Dictionary, recipients: Array[int]) -> void:
    var reward := BattleEngine.experience_reward(defeated, recipients.size())
    for index in recipients:
        var pokemon: Dictionary = caught_pokemon[index]
        await _type_battle_text("%s gained %d EXP. Points!" % [
            PokemonState.display_name(pokemon).to_upper(), reward])
        await _run_experience_progression(pokemon, reward, index, true)
    # Source queues every recipient's CheckEvo after all EXP animations.
    for index in recipients:
        await _check_reward_evolution(caught_pokemon[index], index)

func _finish_enemy_faint() -> void:
    if _next_healthy_enemy_index() < 0 and current_species != "mewtwo" and "unown" not in current_species:
        world.environment_system.play_victory_music()
    BattleEngine.reset_battle_state(battle_enemy)
    BattleEngine.reset_battle_state(battle_player)
    var effort := PokemonState.grant_evs(battle_player, battle_enemy)
    caught_pokemon[battle_party_index] = battle_player
    var recipients := BattleEngine.experience_recipients(caught_pokemon,
        battle_exp_participants, battle_party_index)
    var message := "%s fainted!" % BattleEngine.display_name(battle_enemy)
    if int(effort.get("amount", 0)) > 0:
        message += " +%d %s EV." % [int(effort.amount),
            String(effort.stat).replace("_", " ").to_upper()]
    _update_battle_hud()
    await _type_battle_text(message)
    await get_tree().create_timer(0.175).timeout
    await _award_source_experience(battle_enemy, recipients)
    battle_enemy_party[battle_enemy_party_index] = battle_enemy
    var next_enemy_index := _next_healthy_enemy_index()
    if next_enemy_index >= 0:
        battle_enemy_party_index = next_enemy_index
        var next_member := battle_enemy_party[next_enemy_index] as Dictionary
        battle_enemy = BattleEngine.ensure_pokemon(next_member) if next_member.has("stats") else \
            _make_context_enemy(next_member)
        battle_enemy_party[next_enemy_index] = battle_enemy
        BattleEngine.reset_battle_state(battle_enemy)
        current_species = String(battle_enemy.get("species", "rattata"))
        current_level = int(battle_enemy.get("level", 1))
        battle_enemy_action_count = 0
        _refresh_battle_sprites()
        _update_battle_hud()
        _play_pokemon_cry(battle_enemy)
        var send_message := "%s sent out %s!" % [
            String(battle_context.get("trainer_name", "The opponent")),
            BattleEngine.display_name(battle_enemy)
        ]
        var entry_message := BattleEngine.switch_in_message(battle_enemy,
            [battle_player], battle_field)
        if not entry_message.is_empty(): send_message += " " + entry_message
        await _type_battle_text(send_message)
        await get_tree().create_timer(0.125).timeout
        if int(battle_player.get("hp", 0)) <= 0:
            await _handle_player_faint()
            return
        battle_turn_busy = false
        _show_battle_command_screen()
        return
    var outcome := "victory" if String(battle_context.get("kind", "wild")) == "trainer" else "defeated"
    _end_battle(outcome)

func _next_healthy_enemy_index() -> int:
    for index in range(battle_enemy_party.size()):
        if index == battle_enemy_party_index or typeof(battle_enemy_party[index]) != TYPE_DICTIONARY:
            continue
        var record := battle_enemy_party[index] as Dictionary
        if not record.has("stats"):
            record = _make_context_enemy(record)
            battle_enemy_party[index] = record
        if int(record.get("hp", 0)) > 0:
            return index
    return -1

func _handle_player_faint() -> bool:
    caught_pokemon[battle_party_index] = battle_player
    await _type_battle_text("%s fainted!" % PokemonState.display_name(battle_player))
    await get_tree().create_timer(0.15).timeout
    var available := _healthy_party_indices(true)
    if available.is_empty():
        await _type_battle_text("You are out of usable Pokemon.")
        await get_tree().create_timer(0.175).timeout
        _end_battle("whiteout")
        return true
    _open_battle_party_menu("FORCED")
    var next_index = await battle_party_chosen
    await _switch_battle_party(int(next_index), false, true)
    if int(battle_player.hp) <= 0:
        return await _handle_player_faint()
    await get_tree().create_timer(0.5).timeout
    battle_turn_busy = false
    _show_battle_command_screen()
    return true

func _apply_battle_end_turn() -> void:
    battle_turn_count += 1
    battle_field["turn_count"] = battle_turn_count
    var messages: Array[String] = []
    var player_hp_before := int(battle_player.get("hp", 0))
    var enemy_hp_before := int(battle_enemy.get("hp", 0))
    var player_poisoned := String(battle_player.get("status",""))=="POISON" and not bool(battle_player.volatile.get("action_residual_applied", false))
    var enemy_poisoned := String(battle_enemy.get("status",""))=="POISON" and not bool(battle_enemy.volatile.get("action_residual_applied", false))
    var player_message := BattleEngine.end_turn(battle_player, battle_field, battle_enemy, battle_rng)
    var enemy_message := BattleEngine.end_turn(battle_enemy, battle_field, battle_player, battle_rng)
    if coop_game.active and coop_game.raids.active:await coop_game.raids.sync_damage(enemy_hp_before)
    if not player_message.is_empty():
        messages.append(player_message)
    if not enemy_message.is_empty():
        messages.append(enemy_message)
    if int(battle_field.get("weather_turns", 0)) > 0:
        battle_field.weather_turns = int(battle_field.weather_turns) - 1
        if int(battle_field.weather_turns) <= 0:
            var old_weather := String(battle_field.get("weather", ""))
            battle_field.weather = ""
            messages.append("The %s subsided." % old_weather.replace("_", " ").to_lower())
            _update_battle_field_visuals()
    caught_pokemon[battle_party_index] = battle_player
    await _play_poison_status_feedback(battle_player,true,player_hp_before,player_poisoned)
    await _play_poison_status_feedback(battle_enemy,false,enemy_hp_before,enemy_poisoned)
    await _animate_battle_hp_change(battle_player, player_hp_before,
        int(battle_player.get("hp", 0)), true)
    await _animate_battle_hp_change(battle_enemy, enemy_hp_before,
        int(battle_enemy.get("hp", 0)), false)
    _update_battle_hud()
    if not messages.is_empty():
        await _type_battle_text(" ".join(messages))
        await get_tree().create_timer(0.125).timeout

func _first_usable_move(pokemon: Dictionary) -> String:
    var forced := BattleEngine.forced_move(pokemon)
    if not forced.is_empty():
        return forced
    for move_name in pokemon.get("moves", ["TACKLE"]):
        if BattleEngine.move_is_usable(pokemon, String(move_name)):
            return String(move_name)
    return "STRUGGLE"

func _prepare_enemy_party_records() -> void:
    for index in range(battle_enemy_party.size()):
        if typeof(battle_enemy_party[index]) != TYPE_DICTIONARY:
            continue
        var record := battle_enemy_party[index] as Dictionary
        if not record.has("stats") or not record.has("ivs"):
            battle_enemy_party[index] = _make_context_enemy(record)
    if battle_enemy_party_index >= 0 and battle_enemy_party_index < battle_enemy_party.size():
        battle_enemy_party[battle_enemy_party_index] = battle_enemy

func _choose_enemy_action() -> Dictionary:
    var choice := BattleEngine.choose_ai_action(battle_enemy, [battle_player],
        [battle_enemy], battle_field, battle_rng,
        int(battle_context.get("ai_level", 2 if String(battle_context.get("kind", "")) == "trainer" else 1)))
    if String(battle_context.get("kind", "")) != "trainer":
        choice["kind"] = "move"
        return choice
    var heal_limit := int(battle_context.get("trainer_heals", 1))
    var heals_used := int(battle_context.get("_trainer_heals_used", 0))
    if heals_used < heal_limit and int(battle_enemy.hp) > 0 and \
            int(battle_enemy.hp) * 3 <= int(battle_enemy.max_hp):
        return {"kind":"item", "item":"SUPER POTION"}
    _prepare_enemy_party_records()
    if battle_turn_count > 0 and int(battle_enemy.volatile.get("trap_turns", 0)) <= 0 and \
            not bool(battle_enemy.volatile.get("mean_look", false)):
        var switch_index := BattleEngine.best_switch_index(battle_enemy_party,
            [battle_enemy_party_index], battle_player, battle_field)
        if switch_index >= 0 and (float(choice.get("score", 0.0)) < 18.0 or \
                int(battle_enemy.hp) * 4 <= int(battle_enemy.max_hp)):
            return {"kind":"switch", "index":switch_index}
    choice["kind"] = "move"
    return choice

func _perform_enemy_tactical_action(action: Dictionary) -> void:
    match String(action.get("kind", "move")):
        "item":
            var amount := mini(50, int(battle_enemy.max_hp) - int(battle_enemy.hp))
            battle_enemy.hp = int(battle_enemy.hp) + amount
            battle_context["_trainer_heals_used"] = int(
                battle_context.get("_trainer_heals_used", 0)) + 1
            await _type_battle_text("%s used a SUPER POTION. %s restored %d HP!" % [
                String(battle_context.get("trainer_name", "The Trainer")),
                BattleEngine.display_name(battle_enemy), amount])
            await get_tree().create_timer(0.1).timeout
        "switch":
            await _switch_enemy_party(int(action.get("index", -1)), true)

func _switch_enemy_party(next_index: int, show_message: bool) -> void:
    if next_index < 0 or next_index >= battle_enemy_party.size() or \
            next_index == battle_enemy_party_index:
        return
    _prepare_enemy_party_records()
    var out_message := BattleEngine.switch_out_message(battle_enemy)
    BattleEngine.reset_battle_state(battle_enemy)
    battle_enemy_party[battle_enemy_party_index] = battle_enemy
    battle_enemy_party_index = next_index
    battle_enemy = BattleEngine.ensure_pokemon(battle_enemy_party[next_index])
    BattleEngine.reset_battle_state(battle_enemy)
    battle_enemy_party[next_index] = battle_enemy
    current_species = String(battle_enemy.species)
    current_level = int(battle_enemy.level)
    var spike_layers := int(battle_field.get("enemy_spikes", 0))
    if spike_layers > 0 and not (battle_enemy.types as Array).has("FLYING") and \
            String(battle_enemy.get("ability", "")) != "LEVITATE":
        battle_enemy.hp = maxi(0, int(battle_enemy.hp) -
            maxi(1, int(int(battle_enemy.max_hp) * spike_layers / 8.0)))
    _refresh_battle_sprites()
    _update_battle_hud()
    _play_pokemon_cry(battle_enemy)
    if show_message:
        var message := "%s withdrew its Pokemon and sent out %s!" % [
            String(battle_context.get("trainer_name", "The opponent")),
            BattleEngine.display_name(battle_enemy)]
        if not out_message.is_empty(): message = out_message + " " + message
        var entry := BattleEngine.switch_in_message(battle_enemy, [battle_player], battle_field)
        if not entry.is_empty(): message += " " + entry
        await _type_battle_text(message)
        await get_tree().create_timer(0.1).timeout

func _selected_player_move() -> String:
    var command_actor := _command_pokemon()
    var forced := BattleEngine.forced_move(command_actor)
    if not forced.is_empty():
        return forced
    var moves: Array = command_actor.get("moves", ["TACKLE"])
    if moves.is_empty():
        return "STRUGGLE"
    battle_move_index = clampi(battle_move_index, 0, moves.size() - 1)
    var selected := String(moves[battle_move_index])
    if not BattleEngine.move_is_usable(command_actor, selected):
        return _first_usable_move(command_actor)
    return selected

func _battle_catch() -> void:
    if not battle_active or battle_turn_busy:
        return
    if not bool(battle_context.get("can_catch", true)):
        if String(battle_context.get("kind", "")) == "trainer":
            _start_battle_text("You cannot catch another Trainer's POKEMON!")
        else:
            _start_battle_text("The POKEMON cannot be identified without the SILPH SCOPE.")
        return
    var ball := _best_available_ball()
    if ball.is_empty():
        _start_battle_text("You have no Poke Balls.")
        return
    await _battle_throw_ball(ball)

func _repeat_last_battle_ball() -> void:
    if not battle_active or battle_turn_busy or battle_ui_mode != "COMMAND":
        return
    if String(battle_context.get("kind", "")) == "trainer" or not bool(battle_context.get("can_catch", true)):
        return
    if last_battle_ball.is_empty():
        return
    if int(inventory.get(last_battle_ball, 0)) <= 0:
        return
    await _battle_throw_ball(last_battle_ball)

func _battle_throw_ball(ball: String) -> void:
    if not battle_active or battle_turn_busy or int(inventory.get(ball, 0)) <= 0:
        return
    if coop_game.active and coop_game.raids.active and await coop_game.raids.block_ball(ball):return
    if not bool(battle_context.get("can_catch", true)):
        _start_battle_text("You cannot throw a POKE BALL here.")
        return
    _close_battle_submenu()
    inventory[ball] = int(inventory.get(ball, 0)) - 1
    last_battle_ball = ball
    battle_turn_busy = true
    _show_battle_message_screen()
    await _type_battle_text("Threw %s!" % ball)
    _play_source_battle_sound("throw_pokeball1.ogg")
    var capture_outcome := BattleEngine.capture_result(battle_enemy, battle_player,
        ball, {"turn":battle_turn_count + 1, "night":_world_source_time_of_day() == "night",
        "indoors":String(world.get("active_area_id")) != "OVERWORLD",
        "surfing":String(world.get("active_field_move")) == "SURF",
        "fishing":bool(battle_context.get("fishing", false))}, battle_rng)
    var captured_successfully := capture_outcome == -1
    await _play_source_throw_animation(captured_successfully, 3 if captured_successfully else capture_outcome)
    if captured_successfully:
        # Snapshot before routing the caught Pokemon: source excludes the new catch.
        var capture_recipients := BattleEngine.experience_recipients(
            caught_pokemon, battle_exp_participants, battle_party_index, true)
        if not caught_species.has(current_species):
            caught_species.append(current_species)
        BattleEngine.reset_battle_state(battle_enemy)
        var captured = battle_enemy.duplicate(true)
        if coop_game.active and coop_game.raids.active:coop_game.raids.normalize_capture(captured)
        pokedex_progress.mark(captured, true)
        captured["pokeball"] = ball
        if ball == "HEAL BALL":
            captured.hp = captured.max_hp
            captured.status = ""
            captured.status_counter = 0
            captured.toxic_counter = 0
            BattleEngine.refill_pp(captured)
        elif ball == "FRIEND BALL":
            captured.friendship = 200
        var destination := _route_received_pokemon(captured)
        _play_source_battle_sound("catch_fanfare.ogg")
        await _type_battle_text("Caught %s!" % BattleEngine.display_name(battle_enemy))
        var notice := _received_pokemon_notice(captured, destination)
        if not notice.is_empty(): await _type_battle_text(notice)
        await _award_source_experience(battle_enemy, capture_recipients)
    else:
        await _type_battle_text("%s broke free!" % BattleEngine.display_name(battle_enemy))
        await get_tree().create_timer(0.125).timeout
        var retaliation = _choose_enemy_action()
        await _perform_battle_action(false, String(retaliation.get("move",
            _first_usable_move(battle_enemy))))
        if await _resolve_battle_faints():
            return
        await _apply_battle_end_turn()
        if await _resolve_battle_faints():
            return
        battle_turn_busy = false
        _show_battle_command_screen()
        return

    await get_tree().create_timer(0.35).timeout
    _end_battle("captured")

func _pokemon_evolves_with_moon_stone(pokemon: Dictionary) -> bool:
    var info: Dictionary = PokemonData.info(String(pokemon.get("species", "")))
    for raw_evolution in info.get("evolutions", []):
        if typeof(raw_evolution) != TYPE_DICTIONARY:
            continue
        var evolution: Dictionary = raw_evolution as Dictionary
        if String(evolution.get("method", "")) not in ["EVOLVE_ITEM", "EVOLVE_TRADEITEM"]:
            continue
        var item: String = String(evolution.get("parameter", "")).to_upper().replace("_", " ")
        if item == "MOON STONE":
            return true
    return false

func _battle_ball_bonus(ball: String) -> float:
    var bonus: float = float(BATTLE_BALL_BONUS.get(ball, 1.0))
    var enemy_types: Array = battle_enemy.get("types", [])
    match ball:
        "MASTER BALL", "PARK BALL":
            return 999.0
        "LURE BALL":
            if bool(battle_context.get("fishing", false)): bonus = 3.0
        "DIVE BALL":
            if String(battle_field.get("terrain", "")) == "AQUATIC": bonus = 3.0
        "DUSK BALL":
            if _world_source_time_of_day() == "night" or String(world.get("active_area_id")) != "OVERWORLD": bonus = 3.0
        "NET BALL":
            if enemy_types.has("WATER") or enemy_types.has("BUG"): bonus = 3.0
        "QUICK BALL":
            if battle_turn_count == 0: bonus = 5.0
        "TIMER BALL":
            bonus = minf(4.0, 1.0 + float(battle_turn_count) * 0.3)
        "NEST BALL":
            bonus = maxf(1.0, minf(4.0, (41.0 - float(battle_enemy.level)) / 10.0))
        "DREAM BALL":
            if String(battle_enemy.get("status", "")) == "SLEEP": bonus = 4.0
        "FAST BALL":
            if BattleEngine.effective_stat(battle_enemy, "speed") >= 100: bonus = 4.0
        "HEAVY BALL":
            var weight: float = float(PokemonData.info(String(battle_enemy.species)).get("weight_kg", 0.0))
            bonus = 4.0 if weight >= 300.0 else 3.0 if weight >= 200.0 else 2.0 if weight >= 100.0 else 1.0
        "MOON BALL":
            if _pokemon_evolves_with_moon_stone(battle_enemy): bonus = 4.0
        "LEVEL BALL":
            var ratio: float = float(battle_player.level) / maxf(1.0, float(battle_enemy.level))
            bonus = 8.0 if ratio >= 4.0 else 4.0 if ratio >= 2.0 else 2.0 if ratio > 1.0 else 1.0
        "LOVE BALL":
            var player_gender: String = _resolved_battle_gender(battle_player)
            var enemy_gender: String = _resolved_battle_gender(battle_enemy)
            if (String(battle_player.species) == String(battle_enemy.species) and
                    player_gender in ["male", "female"] and enemy_gender in ["male", "female"] and
                    player_gender != enemy_gender):
                bonus = 8.0
    return bonus

func _best_available_ball() -> String:
    for ball in ["QUICK BALL", "DREAM BALL", "DUSK BALL", "TIMER BALL",
            "NET BALL", "DIVE BALL", "LURE BALL", "LEVEL BALL", "LOVE BALL",
            "FAST BALL", "ULTRA BALL", "GREAT BALL", "HEAVY BALL",
            "NEST BALL", "HEAL BALL", "FRIEND BALL", "MOON BALL",
            "MASTER BALL", "PARK BALL", "POKE BALL"]:
        if int(inventory.get(ball, 0)) > 0:
            return ball
    return ""

func _battle_switch_next() -> void:
    _open_battle_party_menu("PARTY")

func _battle_use_healing_item() -> void:
    _open_battle_item_menu()

func _open_battle_item_menu(reset_selection: bool = true) -> void:
    if not battle_active or battle_turn_busy:
        return
    _close_battle_submenu()
    if reset_selection:
        battle_item_menu_index = 0
    if item_pocket_menu.get_parent() != battle_panel:
        item_pocket_menu.reparent(battle_panel, false)
    item_pocket_context = "BATTLE"
    battle_item_pocket_open = true
    battle_ui_mode = "ITEM_BAG"
    item_pocket_menu.visible = true
    _refresh_battle_item_pocket_menu()

func _refresh_battle_item_pocket_menu() -> void:
    battle_item_menu_names.clear()
    for raw_item_name in ItemData.items_for_pocket(battle_item_pocket_index):
        var item_name := String(raw_item_name)
        if planting_bag_target != null and item_pocket_context == "OVERWORLD":
            if not _planting_bag_item_allowed(item_name): continue
        if int(inventory.get(item_name, 0)) > 0:
            battle_item_menu_names.append(item_name)

    battle_item_menu_index = clampi(battle_item_menu_index, 0,
        battle_item_menu_names.size())
    var label_atlas := AtlasTexture.new()
    label_atlas.atlas = ITEM_BAG_POCKET_TEXTURE
    label_atlas.region = Rect2(battle_item_pocket_index * 41, 0, 41, 24)
    item_pocket_label.texture = label_atlas
    var bag_atlas := AtlasTexture.new()
    bag_atlas.atlas = ITEM_BAG_POCKET_TEXTURE
    bag_atlas.region = Rect2(battle_item_pocket_index * 41, 24, 41, 26)
    item_pocket_bag.texture = bag_atlas

    var entries: Array[String] = battle_item_menu_names.duplicate()
    entries.append("CANCEL")
    var page_start := (
        int(battle_item_menu_index / ITEM_MENU_VISIBLE_ROWS) * ITEM_MENU_VISIBLE_ROWS
    )
    var page_end := mini(page_start + ITEM_MENU_VISIBLE_ROWS, entries.size())
    var item_lines: Array[String] = []
    var quantity_lines: Array[String] = []
    for index in range(page_start, page_end):
        var entry: String = entries[index]
        item_lines.append(entry)
        quantity_lines.append("" if entry == "CANCEL" else
            "x %d" % int(inventory.get(entry, 0)))
    item_pocket_list.text = "\n".join(item_lines)
    item_pocket_quantities.text = "\n".join(quantity_lines)
    var item_font_size := item_pocket_list.get_theme_font_size("font_size")
    var item_pitch := JOHTO_FONT.get_height(item_font_size) + float(
        item_pocket_list.get_theme_constant("line_spacing"))
    # Match the arrow's top to the selected word's actual ink line instead of
    # carrying over the old scaled-background magic number.
    item_pocket_cursor.position.y = roundf(
        item_pocket_list.position.y
        + float(battle_item_menu_index - page_start) * item_pitch
    )
    if battle_item_menu_index < battle_item_menu_names.size():
        item_pocket_description.text = ItemData.description(
            battle_item_menu_names[battle_item_menu_index])
    else:
        item_pocket_description.text = ""

func _switch_battle_item_pocket(direction: int) -> void:
    battle_item_pocket_index = wrapi(battle_item_pocket_index + direction, 0,
        ItemData.POCKET_COUNT)
    battle_item_menu_index = 0
    _refresh_battle_item_pocket_menu()

func _close_battle_item_pocket_menu(return_to_command: bool = true) -> void:
    battle_item_pocket_open = false
    item_pocket_context = ""
    item_pocket_menu.visible = false
    if return_to_command and battle_active:
        _show_battle_command_screen()

func _handle_battle_item_pocket_input(event: InputEvent) -> void:
    if event.is_action_pressed("cancel") or event.is_action_pressed("start"):
        _close_battle_item_pocket_menu()
    elif (event.is_action_pressed("move_left") or
            event.is_action_pressed("shoulder_left")):
        _switch_battle_item_pocket(-1)
    elif (event.is_action_pressed("move_right") or
            event.is_action_pressed("shoulder_right")):
        _switch_battle_item_pocket(1)
    elif event.is_action_pressed("move_up"):
        battle_item_menu_index = wrapi(battle_item_menu_index - 1, 0,
            battle_item_menu_names.size() + 1)
        _refresh_battle_item_pocket_menu()
    elif event.is_action_pressed("move_down"):
        battle_item_menu_index = wrapi(battle_item_menu_index + 1, 0,
            battle_item_menu_names.size() + 1)
        _refresh_battle_item_pocket_menu()
    elif event.is_action_pressed("confirm"):
        _confirm_battle_item_pocket()
    else:
        return
    get_viewport().set_input_as_handled()

func _confirm_battle_item_pocket() -> void:
    if battle_item_menu_index >= battle_item_menu_names.size():
        _close_battle_item_pocket_menu()
        return
    var item_name: String = battle_item_menu_names[battle_item_menu_index]
    if BATTLE_BALL_BONUS.has(item_name):
        _close_battle_item_pocket_menu(false)
        await _battle_throw_ball(item_name)
        return
    if BATTLE_ITEM_RULES.has(item_name):
        battle_pending_item = item_name
        _close_battle_item_pocket_menu(false)
        _open_battle_party_menu("ITEM_TARGET")
        return
    if item_name == "SILPH SCOPE":
        if not bool(battle_enemy.get("is_ghost", false)):
            item_pocket_description.text = "It won't have any effect in battle."
            return
        _close_battle_item_pocket_menu(false)
        await _battle_use_silph_scope()
        return
    if item_name == "POKE DOLL":
        _close_battle_item_pocket_menu(false)
        await _battle_use_poke_doll()
        return
    item_pocket_description.text = "It won't have any effect in battle."

func _battle_use_silph_scope() -> void:
    if not battle_active or battle_turn_busy or int(inventory.get("SILPH SCOPE", 0)) <= 0 or not bool(battle_enemy.get("is_ghost", false)):
        return
    battle_turn_busy = true
    _show_battle_message_screen()
    await _type_battle_text("Used SILPH SCOPE!")
    # Battle.java: 96-tick reveal runs alongside FadeAnim(slow=8), 144 ticks.
    source_effect_playing = true
    var fade := TextureRect.new()
    fade.texture = preload("res://assets/events/source_fade.png")
    fade.position = Vector2.ZERO
    fade.size = Vector2(320, 180)
    fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    battle_panel.add_child(fade)
    var started := preload("res://scripts/game_clock.gd").ticks_usec()
    for frame in range(144):
        fade.modulate.a = (0.0 if frame < 16 else 0.25 if frame < 32 else
            0.5 if frame < 48 else 1.0 if frame < 96 else
            0.75 if frame < 112 else 0.5 if frame < 128 else 0.25)
        if frame == 96:
            battle_enemy["is_ghost"] = false
            pokedex_progress.mark(battle_enemy)
            battle_context["ghost_revealed"] = true
            battle_context["can_catch"] = true
            _refresh_battle_sprites()
            _update_battle_hud()
        while preload("res://scripts/game_clock.gd").ticks_usec() - started < int((frame + 1) * 1000000.0 / 60.0):
            await get_tree().process_frame
    fade.queue_free()
    await _play_source_ghost_intro(false)
    source_effect_playing = false
    await get_tree().create_timer(3.0 * SOURCE_FRAME_TIME).timeout
    await _type_battle_text("Enemy %s was revealed!" % BattleEngine.display_name(battle_enemy))
    await _enemy_action_after_player_choice()

func _play_source_ghost_intro(hidden: bool) -> void:
    var timelines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
        "res://data/source_ghost_intro.json"))
    var species := "ghost" if hidden else String(battle_enemy.species)
    var frames: Array = timelines.get(species, [])
    var texture: Texture2D = GHOST_BATTLE_SHEET if hidden else load("res://assets/events/ghost_intros/%s%s.png" % [species, "-shiny" if PokemonData.is_shiny(battle_enemy) else ""])
    if not GameOptions.enabled("battle_animations"):
        enemy_sprite.texture = _battle_sprite_frame(texture)
        _play_pokemon_cry(battle_enemy)
        return
    var started := preload("res://scripts/game_clock.gd").ticks_usec()
    for tick in range(frames.size()):
        if tick == 4: _play_pokemon_cry(battle_enemy)
        # Ghost frame 4 is intentionally beyond the four-frame source sheet:
        # it is the blank part of the source flicker, not wrapped frame zero.
        enemy_sprite.texture = (_battle_sprite_frame_at(texture, int(frames[tick]))
            if int(frames[tick]) < _battle_sprite_frame_count(texture) else null)
        while preload("res://scripts/game_clock.gd").ticks_usec() - started < int((tick + 1) * 1000000.0 / 60.0):
            await get_tree().process_frame
    enemy_sprite.texture = _battle_sprite_frame(texture)

func _battle_use_poke_doll() -> void:
    if (not battle_active or battle_turn_busy or
            int(inventory.get("POKE DOLL", 0)) <= 0):
        return
    if not bool(battle_context.get("can_run", true)):
        _start_battle_text("The POKE DOLL cannot end this battle.")
        return
    inventory["POKE DOLL"] = int(inventory.get("POKE DOLL", 0)) - 1
    battle_turn_busy = true
    _show_battle_message_screen()
    await _type_battle_text("Used POKE DOLL! Got away safely.")
    await get_tree().create_timer(0.1).timeout
    _end_battle("ran")

func _open_battle_party_menu(mode: String) -> void:
    if not battle_active:
        return
    if battle_turn_busy and mode not in ["FORCED", "BATON_PASS", "DOUBLE_FORCED"]:
        return
    battle_submenu_entries.clear()
    for index in range(mini(6, caught_pokemon.size())):
        var pokemon := BattleEngine.ensure_pokemon(caught_pokemon[index])
        caught_pokemon[index] = pokemon
        battle_submenu_entries.append({"index":index, "pokemon":pokemon})
    if battle_submenu_entries.is_empty():
        _start_battle_text("Your party is empty.")
        return
    battle_submenu_mode = mode
    battle_party_action_open = false
    battle_party_action_panel.visible = false
    battle_submenu_index = clampi(battle_party_index, 0, battle_submenu_entries.size() - 1)
    if mode in ["FORCED", "BATON_PASS", "DOUBLE_FORCED"] and \
            battle_submenu_index in [battle_party_index, battle_partner_party_index]:
        for entry_index in range(battle_submenu_entries.size()):
            var candidate: Dictionary = battle_submenu_entries[entry_index].pokemon
            if (
                    entry_index not in [battle_party_index, battle_partner_party_index]
                    and int(candidate.hp) > 0
                    and not bool(candidate.get("is_egg", false))
                ):
                battle_submenu_index = entry_index
                break
    battle_submenu.visible = true
    _refresh_battle_submenu()

func _handle_battle_submenu_input(event: InputEvent) -> void:
    if battle_submenu_entries.is_empty():
        _close_battle_submenu()
        return
    if battle_party_action_open:
        if event.is_action_pressed("move_up"):
            battle_party_action_index = wrapi(battle_party_action_index - 1, 0,
                battle_party_action_entries.size())
            _refresh_battle_party_action_menu()
        elif event.is_action_pressed("move_down"):
            battle_party_action_index = wrapi(battle_party_action_index + 1, 0,
                battle_party_action_entries.size())
            _refresh_battle_party_action_menu()
        elif event.is_action_pressed("confirm"):
            _activate_battle_party_action()
        elif event.is_action_pressed("cancel") or event.is_action_pressed("start"):
            battle_party_action_open = false
            battle_party_action_panel.visible = false
        else:
            return
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("move_up"):
        battle_submenu_index = wrapi(battle_submenu_index - 1, 0, battle_submenu_entries.size())
        _refresh_battle_submenu()
    elif event.is_action_pressed("move_down"):
        battle_submenu_index = wrapi(battle_submenu_index + 1, 0, battle_submenu_entries.size())
        _refresh_battle_submenu()
    elif event.is_action_pressed("move_left"):
        battle_submenu_index = maxi(0, battle_submenu_index - 6)
        _refresh_battle_submenu()
    elif event.is_action_pressed("move_right"):
        battle_submenu_index = mini(battle_submenu_entries.size() - 1,
            battle_submenu_index + 6)
        _refresh_battle_submenu()
    elif event.is_action_pressed("confirm"):
        _confirm_battle_submenu()
    elif event.is_action_pressed("cancel"):
        if battle_submenu_mode in ["FORCED", "BATON_PASS", "DOUBLE_FORCED"]:
            _start_battle_text("Choose a Pokemon able to battle.")
        elif battle_submenu_mode == "ITEM_TARGET":
            _close_battle_submenu()
            _open_battle_item_menu(false)
        elif battle_submenu_mode == "DOUBLE_TARGET":
            _close_battle_submenu()
            battle_double_pending_move = ""
            _open_battle_move_menu()
        else:
            _close_battle_submenu()
    else:
        return
    get_viewport().set_input_as_handled()

func _confirm_battle_submenu() -> void:
    if battle_submenu_entries.is_empty() or battle_turn_busy and battle_submenu_mode not in [
            "FORCED", "BATON_PASS", "DOUBLE_FORCED"]:
        return
    var entry: Dictionary = battle_submenu_entries[battle_submenu_index]
    if battle_submenu_mode == "DOUBLE_TARGET":
        _store_double_player_action(battle_double_pending_move,
            int(entry.get("target_slot", 0)))
        return
    if battle_submenu_mode == "ITEM":
        var item_name := String(entry.name)
        if String(entry.kind) == "ball":
            await _battle_throw_ball(item_name)
        else:
            battle_pending_item = item_name
            _open_battle_party_menu("ITEM_TARGET")
        return
    var party_index := int(entry.index)
    if battle_submenu_mode == "ITEM_TARGET":
        if not _can_use_battle_item_on(battle_pending_item, party_index):
            return
        await _use_battle_item_on(battle_pending_item, party_index)
        return
    if bool((entry.pokemon as Dictionary).get("is_egg", false)):
        _start_battle_text("An EGG cannot battle.")
        return
    if battle_submenu_mode == "PARTY":
        _open_battle_party_action_menu()
        return
    if party_index in [battle_party_index, battle_partner_party_index] or \
            int((entry.pokemon as Dictionary).hp) <= 0:
        battle_party_action_open = false
        battle_party_action_panel.visible = false
        battle_party_prompt.text = "Choose another Pokemon able to battle."
        return
    if battle_submenu_mode == "DOUBLE_SWITCH":
        var switching_actor := _command_pokemon()
        if int(switching_actor.volatile.get("trap_turns", 0)) > 0 or \
                bool(switching_actor.volatile.get("mean_look", false)):
            _start_battle_text("%s cannot switch out!" % PokemonState.display_name(switching_actor))
            return
        _close_battle_submenu()
        battle_double_actions.append({
            "kind":"switch", "side":"player", "slot":battle_double_command_slot,
            "switch_index":party_index, "move":"", "target_slot":-1,
            "spread":false
        })
        _advance_double_command_slot()
        return
    _close_battle_submenu()
    if is_instance_valid(coop_game.pvp) and coop_game.pvp.active:
        coop_game.pvp.submit({"kind":"switch","index":party_index})
        return
    battle_party_chosen.emit(party_index)

func _refresh_battle_submenu() -> void:
    if battle_submenu_entries.is_empty():
        return
    var uses_party_view := battle_submenu_mode not in ["ITEM", "DOUBLE_TARGET"]
    battle_party_view.visible = uses_party_view
    $UI/BattlePanel/BattleSubmenu/Dim.visible = not uses_party_view
    $UI/BattlePanel/BattleSubmenu/Window.visible = not uses_party_view
    if uses_party_view:
        _refresh_battle_party_view()
        return
    var page_start := int(battle_submenu_index / 6) * 6
    var page_end := mini(page_start + 6, battle_submenu_entries.size())
    var lines: Array[String] = []
    for index in range(page_start, page_end):
        var entry: Dictionary = battle_submenu_entries[index]
        if battle_submenu_mode == "DOUBLE_TARGET":
            var target: Dictionary = entry.pokemon
            lines.append("%-12s L%02d  HP %3d/%3d" % [
                BattleEngine.display_name(target).left(12), int(target.level),
                int(target.hp), int(target.max_hp)])
        elif battle_submenu_mode == "ITEM":
            lines.append("%-18s x%d" % [String(entry.name), int(inventory.get(String(entry.name), 0))])
        else:
            var pokemon: Dictionary = entry.pokemon
            if bool(pokemon.get("is_egg", false)):
                lines.append("EGG        --  ---/---")
                continue
            var active := " ACTIVE" if int(entry.index) == battle_party_index else ""
            var status := String(pokemon.get("status", ""))
            if not status.is_empty():
                status = " " + status.left(3)
            lines.append("%-10s L%02d %3d/%3d%s%s" % [
                PokemonState.display_name(pokemon).left(10), int(pokemon.level),
                int(pokemon.hp), int(pokemon.max_hp), status, active])
    battle_submenu_list.text = "\n".join(lines)
    _align_menu_tick(battle_submenu_cursor, battle_submenu_list, battle_submenu_index - page_start)
    if battle_submenu_mode == "DOUBLE_TARGET":
        battle_submenu_title.text = "CHOOSE A TARGET"
        battle_submenu_hint.text = "A TARGET   B MOVES"
    elif battle_submenu_mode == "ITEM":
        battle_submenu_title.text = "BATTLE ITEMS  %d/%d" % [battle_submenu_index + 1, battle_submenu_entries.size()]
        battle_submenu_hint.text = "A USE   B BACK   LEFT/RIGHT PAGE"
    elif battle_submenu_mode == "ITEM_TARGET":
        battle_submenu_title.text = "%s: CHOOSE TARGET" % battle_pending_item
        battle_submenu_hint.text = "A USE   B ITEMS"
    elif battle_submenu_mode == "BATON_PASS":
        battle_submenu_title.text = "BATON PASS: CHOOSE POKEMON"
        battle_submenu_hint.text = "A SELECT"
    elif battle_submenu_mode == "FORCED":
        battle_submenu_title.text = "CHOOSE NEXT POKEMON"
        battle_submenu_hint.text = "A SELECT"
    elif battle_submenu_mode == "DOUBLE_FORCED":
        battle_submenu_title.text = "REPLACE FAINTED POKEMON"
        battle_submenu_hint.text = "A SELECT"
    elif battle_submenu_mode == "DOUBLE_SWITCH":
        battle_submenu_title.text = "SWITCH ACTIVE POKEMON"
        battle_submenu_hint.text = "A SWITCH   B BACK"
    else:
        battle_submenu_title.text = "POKEMON  %d/%d" % [battle_submenu_index + 1, battle_submenu_entries.size()]
        battle_submenu_hint.text = "A SWITCH   B BACK   LEFT/RIGHT PAGE"

func _close_battle_submenu() -> void:
    battle_submenu_mode = ""
    battle_submenu_entries.clear()
    battle_party_action_open = false
    battle_party_action_panel.visible = false
    battle_party_view.visible = false
    $UI/BattlePanel/BattleSubmenu/Dim.visible = true
    $UI/BattlePanel/BattleSubmenu/Window.visible = true
    battle_submenu.visible = false

func _refresh_battle_party_view() -> void:
    if battle_submenu_entries.is_empty():
        return
    battle_submenu_index = clampi(battle_submenu_index, 0,
        battle_submenu_entries.size() - 1)
    var visible_party: Array = []
    for entry in battle_submenu_entries:
        visible_party.append((entry as Dictionary).pokemon)
    _refresh_party_list_rows(battle_party_rows, visible_party,
        battle_submenu_index)
    battle_party_prompt.text = {
        "ITEM_TARGET":"Use %s on which POKEMON?" % battle_pending_item,
        "FORCED":"Choose next POKEMON.",
        "BATON_PASS":"Choose a POKEMON.",
        "DOUBLE_FORCED":"Choose a replacement.",
        "DOUBLE_SWITCH":"Switch which POKEMON?"
    }.get(battle_submenu_mode, "Choose a POKEMON.")

func _open_battle_party_action_menu() -> void:
    var pokemon := battle_submenu_entries[battle_submenu_index].pokemon as Dictionary
    battle_party_action_entries = _pokemon_world_actions(
        String(pokemon.get("species", "")), pokemon)
    battle_party_action_index = 0
    battle_party_action_open = true
    battle_party_action_panel.visible = true
    _refresh_battle_party_action_menu()

func _refresh_battle_party_action_menu() -> void:
    battle_party_action_index = wrapi(battle_party_action_index, 0,
        battle_party_action_entries.size())
    _refresh_source_action_rows(battle_party_action_list, battle_party_action_cursor,
        battle_party_action_entries, battle_party_action_index)

func _activate_battle_party_action() -> void:
    var action := String(battle_party_action_entries[battle_party_action_index])
    var entry := battle_submenu_entries[battle_submenu_index]
    if action == "CANCEL":
        battle_party_action_open = false
        battle_party_action_panel.visible = false
        return
    if action == "STATS":
        battle_party_action_open = false
        battle_party_action_panel.visible = false
        _open_pokemon_stats(entry.pokemon as Dictionary, "BATTLE")
        return
    if action == "SWITCH":
        await _switch_from_battle_party_action(int(entry.index))
        return
    battle_party_action_open = false
    battle_party_action_panel.visible = false
    battle_party_prompt.text = "That action cannot be used during battle."

func _switch_from_battle_party_action(party_index: int) -> void:
    if is_instance_valid(coop_game.pvp) and coop_game.pvp.active:
        coop_game.pvp.submit({"kind":"switch","index":party_index})
        return
    if party_index in [battle_party_index, battle_partner_party_index] or \
            int((battle_submenu_entries[battle_submenu_index].pokemon as Dictionary).hp) <= 0:
        battle_party_action_open = false
        battle_party_action_panel.visible = false
        battle_party_prompt.text = "Choose another Pokemon able to battle."
        return
    if int(battle_player.volatile.get("trap_turns", 0)) > 0 or \
            bool(battle_player.volatile.get("mean_look", false)):
        battle_party_action_open = false
        battle_party_action_panel.visible = false
        battle_party_prompt.text = "%s cannot switch out!" % PokemonState.display_name(battle_player)
        return
    _close_battle_submenu()
    battle_turn_busy = true
    await _switch_battle_party(party_index, false, true)
    if await _resolve_battle_faints():
        return
    await _enemy_action_after_player_choice()

func _healthy_party_indices(exclude_active: bool) -> Array[int]:
    var result: Array[int] = []
    for index in range(caught_pokemon.size()):
        if exclude_active and index == battle_party_index:
            continue
        var pokemon := BattleEngine.ensure_pokemon(caught_pokemon[index])
        caught_pokemon[index] = pokemon
        if int(pokemon.hp) > 0 and not bool(pokemon.get("is_egg", false)):
            result.append(index)
    return result

func _switch_battle_party(next_index: int, preserve_state: bool,
        show_message: bool) -> void:
    if not battle_exp_participants.has(next_index): battle_exp_participants.append(next_index)
    var passed_stages := (battle_player.get("stages", {}) as Dictionary).duplicate(true)
    var passed_volatile := {}
    if preserve_state:
        for key in ["substitute_hp", "confuse_turns", "focus_energy"]:
            if battle_player.volatile.has(key):
                passed_volatile[key] = battle_player.volatile[key]
    var out_message := BattleEngine.switch_out_message(battle_player)
    BattleEngine.reset_battle_state(battle_player)
    caught_pokemon[battle_party_index] = battle_player
    battle_party_index = next_index
    battle_player = BattleEngine.ensure_pokemon(caught_pokemon[next_index])
    BattleEngine.reset_battle_state(battle_player)
    if preserve_state:
        battle_player.stages = passed_stages
        for key in passed_volatile.keys():
            battle_player.volatile[key] = passed_volatile[key]
    caught_pokemon[next_index] = battle_player
    battle_move_index = 0
    var spike_layers := int(battle_field.get("player_spikes", 0))
    if spike_layers > 0 and not (battle_player.types as Array).has("FLYING") and \
            String(battle_player.get("ability", "")) != "LEVITATE":
        var spike_damage := maxi(1, int(int(battle_player.max_hp) * spike_layers / 8.0))
        battle_player.hp = maxi(0, int(battle_player.hp) - spike_damage)
    _refresh_battle_sprites()
    _update_battle_hud()
    _play_pokemon_cry(battle_player)
    if show_message:
        var message := "Go, %s!" % PokemonState.display_name(battle_player)
        if not out_message.is_empty(): message = out_message + " " + message
        var entry := BattleEngine.switch_in_message(battle_player, [battle_enemy], battle_field)
        if not entry.is_empty(): message += " " + entry
        await _type_battle_text(message)
        await get_tree().create_timer(0.1).timeout

func _request_baton_pass() -> void:
    if _healthy_party_indices(true).is_empty():
        await _type_battle_text("But there was nobody to receive the pass!")
        return
    _open_battle_party_menu("BATON_PASS")
    var next_index = await battle_party_chosen
    await _switch_battle_party(int(next_index), true, true)

func _request_forced_player_switch() -> void:
    if _healthy_party_indices(true).is_empty():
        await _type_battle_text("But it failed!")
        return
    _open_battle_party_menu("FORCED")
    var next_index = await battle_party_chosen
    await _switch_battle_party(int(next_index), false, true)

func _can_use_battle_item_on(item_name: String, party_index: int) -> bool:
    var pokemon := BattleEngine.ensure_pokemon(caught_pokemon[party_index])
    caught_pokemon[party_index] = pokemon
    if bool(pokemon.get("is_egg", false)):
        _start_battle_text("That item cannot be used on an EGG.")
        return false
    var rule: Dictionary = BATTLE_ITEM_RULES.get(item_name, {})
    match String(rule.get("kind", "")):
        "heal":
            if int(pokemon.hp) <= 0 or int(pokemon.hp) >= int(pokemon.max_hp):
                _start_battle_text("That Pokemon does not need HP restored.")
                return false
        "full_restore":
            if int(pokemon.hp) <= 0 or (int(pokemon.hp) >= int(pokemon.max_hp) and String(pokemon.status).is_empty()):
                _start_battle_text("That Pokemon does not need restoring.")
                return false
        "status":
            var cures := String(rule.get("status", "ANY"))
            if int(pokemon.hp) <= 0 or String(pokemon.status).is_empty() or (cures != "ANY" and String(pokemon.status) != cures):
                _start_battle_text("That item will not help this Pokemon.")
                return false
        "confusion":
            if not (pokemon.volatile as Dictionary).has("confuse_turns"):
                _start_battle_text("That Pokemon is not confused.")
                return false
        "revive":
            if int(pokemon.hp) > 0:
                _start_battle_text("That Pokemon has not fainted.")
                return false
        _:
            return false
    return true

func _use_battle_item_on(item_name: String, party_index: int) -> void:
    if is_instance_valid(coop_game.pvp) and coop_game.pvp.active:
        coop_game.pvp.submit({"kind":"item","item":item_name,"index":party_index})
        return
    var pokemon := BattleEngine.ensure_pokemon(caught_pokemon[party_index])
    var rule: Dictionary = BATTLE_ITEM_RULES[item_name]
    var detail := ""
    match String(rule.kind):
        "heal":
            var healed := mini(int(rule.amount), int(pokemon.max_hp) - int(pokemon.hp))
            pokemon.hp = int(pokemon.hp) + healed
            detail = "Restored %d HP!" % healed
        "full_restore":
            var healed := int(pokemon.max_hp) - int(pokemon.hp)
            pokemon.hp = pokemon.max_hp
            pokemon.status = ""
            pokemon.status_counter = 0
            pokemon.toxic_counter = 0
            detail = "Restored %d HP and cured status!" % healed
        "status":
            pokemon.status = ""
            pokemon.status_counter = 0
            pokemon.toxic_counter = 0
            detail = "Its status was cured!"
        "confusion":
            pokemon.volatile.erase("confuse_turns")
            detail = "Its confusion was cured!"
        "revive":
            pokemon.hp = maxi(1, int(int(pokemon.max_hp) * float(rule.fraction)))
            detail = "It returned with %d HP!" % int(pokemon.hp)
    inventory[item_name] = maxi(0, int(inventory.get(item_name, 0)) - 1)
    caught_pokemon[party_index] = pokemon
    if party_index == battle_party_index:
        battle_player = pokemon
    elif party_index == battle_partner_party_index:
        battle_player_partner = pokemon
    battle_pending_item = ""
    _close_battle_submenu()
    battle_turn_busy = true
    _show_battle_message_screen()
    _update_battle_hud()
    await _type_battle_text("Used %s on %s. %s" % [item_name,
        PokemonState.display_name(pokemon), detail])
    await get_tree().create_timer(0.1).timeout
    if battle_is_double:
        battle_turn_busy = false
        _advance_double_command_slot()
        return
    await _enemy_action_after_player_choice()

func _enemy_action_after_player_choice() -> void:
    _show_battle_message_screen()
    var action := _choose_enemy_action()
    if String(action.get("kind", "move")) == "move":
        await _perform_battle_action(false, String(action.get("move",
            _first_usable_move(battle_enemy))))
    else:
        await _perform_enemy_tactical_action(action)
    if not battle_active:
        return
    if await _resolve_battle_faints():
        return
    await _apply_battle_end_turn()
    if await _resolve_battle_faints():
        return
    battle_turn_busy = false
    _show_battle_command_screen()

func _battle_run() -> void:
    if is_instance_valid(coop_game.pvp) and coop_game.pvp.active:
        coop_game.pvp.submit({"kind":"run"})
        return
    if not battle_active or battle_turn_busy:
        return

    if not bool(battle_context.get("can_run", true)):
        _start_battle_text("There is no running from this battle!")
        return

    if int(battle_player.volatile.get("trap_turns", 0)) > 0 or bool(battle_player.volatile.get("mean_look", false)):
        _start_battle_text("%s cannot escape!" % PokemonState.display_name(battle_player))
        return
    battle_turn_busy = true
    _show_battle_message_screen()
    battle_run_attempts += 1
    var player_speed := BattleEngine.effective_stat(battle_player, "speed")
    var enemy_speed := BattleEngine.effective_stat(battle_enemy, "speed")
    var escaped := player_speed >= enemy_speed
    if not escaped:
        var threshold := int(float(player_speed) * 128.0 / maxf(1.0, float(enemy_speed)))
        threshold += 30 * battle_run_attempts
        escaped = battle_rng.randi_range(0, 255) < threshold
    if escaped:
        await _type_battle_text("Got away safely.")
        await get_tree().create_timer(0.1).timeout
        _end_battle("ran")
        return
    await _type_battle_text("Couldn't get away!")
    await get_tree().create_timer(0.1).timeout
    await _enemy_action_after_player_choice()

func _end_battle(outcome: String = "") -> void:
    var ending_pvp=is_instance_valid(coop_game.pvp) and coop_game.pvp.active
    var ending_raid=coop_game.active and coop_game.raids.active
    var ending_population=coop_game.active and not coop_game.population_battles.claim.is_empty()
    var ending_event=coop_game.active and coop_game.events.active
    if ending_pvp:outcome=""
    if is_instance_valid(source_boss):
        source_boss.set_palette_stage(0)
        source_boss.queue_free()
        source_boss=null
    source_boss_action_count=0
    if is_instance_valid(source_mewtwo):
        source_mewtwo.queue_free()
        source_mewtwo = null
    player_battle_sprite.modulate = Color.WHITE
    if world.roaming_ghosts != null and String(battle_context.get("id", "")).begins_with("roaming_ghost_"):
        world.roaming_ghosts.complete(String(battle_context.id), outcome, battle_enemy)
    if world.source_night_events != null and String(battle_context.get("id", "")).begins_with("source_night_"):
        world.source_night_events.complete(outcome)
    var ended_wild_battle := String(battle_context.get("kind", "")) == "wild"
    if not outcome.is_empty() and not battle_result_sent:
        battle_result_sent = true
        if not ending_raid and not ending_population and not ending_event and world.has_method("complete_battle_event"):
            world.call("complete_battle_event", {
                "outcome": outcome,
                "context": battle_context.duplicate(true),
                "mine_pokemon": battle_enemy.duplicate(true) if battle_context.has("mine_pokemon_id") else {}
            })
    battle_active = false
    battle_turn_busy = false
    battle_text_busy = false
    battle_text_accumulator = 0.0
    battle_status.visible_characters = -1
    battle_ui_mode = "INTRO"
    _close_battle_submenu()
    battle_pending_item = ""
    battle_item_pocket_open = false
    item_pocket_context = ""
    battle_item_menu_names.clear()
    battle_item_menu_index = 0
    item_pocket_menu.visible = false
    battle_audio.stop()
    battle_move_animation.texture = null
    _clear_battle_capture_ball()
    for index in range(caught_pokemon.size()):
        if typeof(caught_pokemon[index]) == TYPE_DICTIONARY:
            BattleEngine.reset_battle_state(caught_pokemon[index])
            caught_pokemon[index].erase("_double_faint_announced")
            caught_pokemon[index].erase("_double_faint_processed")
    # These battle dictionaries are also stored in the party arrays. Replacing
    # the references preserves those party records; clear() erased Machop and
    # made ensure_pokemon rebuild the empty entry as its Rattata fallback.
    battle_player = {}
    battle_enemy = {}
    battle_player_partner = {}
    battle_enemy_partner = {}
    battle_context = {}
    battle_enemy_party.clear()
    battle_enemy_party_index = 0
    battle_enemy_action_count = 0
    battle_is_double = false
    battle_partner_party_index = -1
    battle_enemy_partner_party_index = -1
    battle_double_command_slot = 0
    battle_double_actions.clear()
    battle_double_pending_move = ""
    battle_double_replacement_slot = -1
    player_partner_sprite.visible = false
    enemy_partner_sprite.visible = false
    double_status.visible = false
    _set_double_battle_layout()
    battle_field.clear()
    battle_panel.visible = false
    if world.has_method("set_environment_battle_active"):
        world.call("set_environment_battle_active", false)
    if coop_game.active and not coop_game.wild.encounter.is_empty():
        if not await coop_game.wild.finish_encounter(outcome):return
    if ending_raid:
        if not await coop_game.raids.finish(outcome):return
    if ending_population:
        if not await coop_game.population_battles.finish(outcome):return
    if ending_event:
        if not await coop_game.events.finish(outcome):return
    if outcome == "whiteout" and world.has_method("respawn_after_whiteout"):
        _ensure_machop_lead(true)
        world.call("clear_active_field_move", false)
        if is_instance_valid(coop_game) and coop_game.active:
            if not await coop_game.rest.before_whiteout():return
        world.call("respawn_after_whiteout")
        world.player.velocity=Vector2.ZERO
        world.player.camera.reset_smoothing()
        if coop_game.active:await coop_game.checkpoint_player()
        _show_message("You are being returned to the last safe place!")
    world.set_gameplay_enabled(true)
    if ended_wild_battle and world.has_method("begin_encounter_grace"):
        world.call("begin_encounter_grace")
    if ending_pvp:coop_game.pvp.restore()

func _load_battle_animation_manifest() -> void:
    const MANIFEST_PATH = "res://assets/battle_animations/manifest.json"
    battle_animation_manifest = {}
    if not FileAccess.file_exists(MANIFEST_PATH):
        return
    var file = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        battle_animation_manifest = parsed

func _play_status_on_pokemon(animation: String, pokemon: Dictionary, player_side: bool) -> void:
    # Source LoadAndPlayAnimation selects enemy_gsc for the player's Pokemon:
    # sheet names describe the attacking side, not the status owner.
    var original_position := battle_move_animation.position
    if battle_is_double:
        if player_side and is_same(pokemon, battle_player_partner):
            battle_move_animation.position += player_partner_sprite.position-player_battle_sprite.position
        elif not player_side and is_same(pokemon, battle_enemy_partner):
            battle_move_animation.position += enemy_partner_sprite.position-enemy_sprite.position
    await _play_battle_feedback(animation, not player_side, {"damage":0})
    battle_move_animation.position = original_position

func _battle_status_snapshot(pokemon: Dictionary) -> Dictionary:
    var volatile: Dictionary = pokemon.get("volatile", {})
    return {"status":String(pokemon.get("status", "")),
        "confused":int(volatile.get("confuse_turns", 0)) > 0,
        "attracted":bool(volatile.get("attract", false))}

func _play_new_status_feedback(pokemon: Dictionary, player_side: bool,
        before: Dictionary, result: Dictionary) -> void:
    if int(pokemon.get("hp", 0)) <= 0 or not bool(result.get("executed", false)):
        return
    var after := _battle_status_snapshot(pokemon)
    var applied: Array[String] = []
    if String(before.status).is_empty() and not String(after.status).is_empty():
        applied.append(String(after.status))
    if not bool(before.confused) and bool(after.confused): applied.append("CONFUSION")
    if not bool(before.attracted) and bool(after.attracted): applied.append("ATTRACT")
    for status in applied:
        # Battle.getAttackAction: hit effects wait 49 frames, then the status
        # animation (except sleep/poison/attract), 30 frames, then the message.
        if int(result.get("damage", 0)) > 0:
            await get_tree().create_timer(49.0 / 60.0).timeout
        var animation := String({"BURN":"status_burn", "FREEZE":"status_freeze",
            "PARALYSIS":"status_paralyze", "CONFUSION":"status_confuse"}.get(status, ""))
        if not animation.is_empty():
            await _play_status_on_pokemon(animation, pokemon, player_side)
        await get_tree().create_timer(30.0 / 60.0).timeout
        var description := String({"BURN":"was burned!", "FREEZE":"was frozen solid!",
            "PARALYSIS":"was PARALYZED! It might not be able to attack!",
            "SLEEP":"fell asleep!", "POISON":"was poisoned!",
            "CONFUSION":"became confused!", "ATTRACT":"fell in love!"}.get(status, ""))
        if not description.is_empty():
            await _type_battle_text("%s %s" % [BattleEngine.display_name(pokemon), description])

func _play_poison_status_feedback(pokemon: Dictionary, player_side: bool,
        hp_before: int, poisoned_before: bool) -> void:
    if poisoned_before and int(pokemon.get("hp",0))<hp_before and             String(pokemon.get("ability","")) not in ["POISON HEAL","MAGIC GUARD"]:
        await _play_status_on_pokemon("status_poison",pokemon,player_side)

func _play_blocked_status_feedback(attacker: Dictionary, player_side: bool,
        message: String) -> void:
    var status: String = String(attacker.get("status", "")).to_upper()
    var lower_message: String = message.to_lower()
    if status == "SLEEP" and "asleep" in lower_message:
        await _play_status_on_pokemon("status_sleep", attacker, player_side)
    elif "confused" in lower_message or "confusion" in lower_message:
        await _play_status_on_pokemon("status_confuse", attacker, player_side)
    elif status == "PARALYSIS" and "paralyzed" in lower_message:
        await _play_status_on_pokemon("status_paralyze", attacker, player_side)

func _play_battle_feedback(move_name: String, player_attacks: bool,
        result: Dictionary, target: Dictionary = {}) -> void:
    var normalized := move_name.to_lower().replace(" ", "_")
    var hits := maxi(1,int(result.get("hits",1)))
    var shown_hp := int(result.get("defender_hp_before", 0))
    var show_each_hit := hits > 1 and not target.is_empty() and not bool(result.get("hit_substitute", false))
    var alternating := normalized in ["double_kick","doubleslap","fury_swipes"]
    for hit in range(hits):
        var frame_move := normalized + ("_left" if hit % 2 == 0 else "_right") if alternating else normalized
        await _play_source_battle_feedback(frame_move,player_attacks,result)
        var last_hit := hit == hits - 1
        # Java places effectiveness before the final HP change, not after it.
        if last_hit and int(result.get("damage",0)) > 0 and normalized not in ["neutral_effective","super_effective","not_very_effective"]:
            var effectiveness := float(result.get("effectiveness",1.0))
            var hit_name := "super_effective" if effectiveness>1.0 else "not_very_effective" if effectiveness<1.0 else "neutral_effective"
            await _play_source_battle_feedback(hit_name,player_attacks,{"damage":0})
        if show_each_hit:
            # Endure, Sturdy and Disguise may reduce the final applied damage.
            # Never animate past the HP that the mechanics actually retained.
            var next_hp := maxi(int(target.get("hp", 0)), shown_hp-int(result.hit_damages[hit]))
            await _animate_visible_battle_hp(target, shown_hp, next_hp)
            shown_hp = next_hp
        if not last_hit:
            await get_tree().create_timer(43.0/60.0).timeout
            var critical_hits: Array = result.get("hit_criticals", [])
            if hit < critical_hits.size() and bool(critical_hits[hit]):
                await _type_battle_text("Critical hit!")
    if show_each_hit: result["hp_feedback_complete"] = true

func _play_source_battle_feedback(move_name: String, player_attacks: bool,
        result: Dictionary) -> void:
    if not GameOptions.enabled("battle_animations"):
        return
    var procedural_key := move_name.to_upper().replace(" ","_")
    if procedural_key=="CRUSH_GRIP" or (is_instance_valid(source_boss) and source_boss.kind=="mega_gengar" and not player_attacks and procedural_key in ["SHADOW_CLAW","NIGHT_SHADE","LICK"]):
        var procedural := preload("res://scripts/source_procedural_attack.gd").new()
        battle_panel.add_child(procedural)
        procedural.setup(self,procedural_key,player_attacks)
        source_effect_playing=true
        await procedural.play()
        procedural.queue_free()
        source_effect_playing=false
        if is_instance_valid(source_boss):enemy_sprite.texture=source_boss.body
        return
    var normalized := move_name.to_lower().replace(" ", "_")
    var source_key := _battle_source_key(normalized,
        "player" if player_attacks else "enemy")
    var audio_entries: Dictionary = battle_animation_manifest.get("audio", {})
    var audio_path := String(audio_entries.get(source_key,
        audio_entries.get(normalized, "")))
    if not audio_path.is_empty() and ResourceLoader.exists(audio_path):
        battle_audio.stream = load(audio_path) as AudioStream
        AudioBalance.apply(battle_audio)
        battle_audio.play()

    var animations: Dictionary = battle_animation_manifest.get("animations", {})
    var animation: Dictionary = animations.get(source_key, {})
    # Status moves without authored source frames intentionally have no made-up
    # lunge/pulse. Only the source animation library is rendered here.
    if animation.is_empty():
        return
    var raw_sheets = animation.get("sheets", [])
    var sheets: Array = raw_sheets if typeof(raw_sheets) == TYPE_ARRAY else []
    if sheets.is_empty():
        var compatibility_path := String(animation.get("path", ""))
        if not compatibility_path.is_empty():
            sheets.append({
                "path": compatibility_path,
                "start_frame": 0,
                "frames": int(animation.get("frames", 0))
            })
    var frames := int(animation.get("frames", 0))
    var visual_end_frame := int(animation.get("visual_end_frame", frames - 1))
    frames = mini(frames, visual_end_frame + 1)
    var columns := maxi(1, int(animation.get("columns", 4)))
    var frame_width := int(animation.get("frame_width", 160))
    var frame_height := int(animation.get("frame_height", 144))
    var frame_time := float(animation.get("frame_time", 1.0 / 60.0))
    var directives: Dictionary = animation.get("directives", {})
    var player_origin := player_battle_sprite.position
    var enemy_origin := enemy_sprite.position
    var animation_origin := battle_move_animation.position
    var player_scale := player_battle_sprite.scale
    var enemy_scale := enemy_sprite.scale
    var player_modulate := player_battle_sprite.modulate
    var enemy_modulate := enemy_sprite.modulate
    var player_visible := player_battle_sprite.visible
    var enemy_visible := enemy_sprite.visible
    var player_hud_visible := player_hud.visible
    var enemy_hud_visible := enemy_hud.visible
    var source_hud_visible := source_single_hud.visible
    var active_sheet_path := ""
    var active_sheet: Texture2D = null
    var effects = preload("res://scripts/source_battle_effects.gd").new()
    effects.begin(self, source_key)
    source_effect_playing = true
    var animation_deadline := preload("res://scripts/game_clock.gd").ticks_usec()
    for frame_index in range(frames):
        var sheet_entry: Dictionary = {}
        for raw_sheet in sheets:
            if typeof(raw_sheet) != TYPE_DICTIONARY:
                continue
            var candidate := raw_sheet as Dictionary
            var start := int(candidate.get("start_frame", 0))
            var length := int(candidate.get("frames", 0))
            if frame_index >= start and frame_index < start + length:
                sheet_entry = candidate
                break
        if sheet_entry.is_empty():
            continue
        var sheet_path := String(sheet_entry.get("path", ""))
        if sheet_path != active_sheet_path:
            active_sheet_path = sheet_path
            active_sheet = battle_animation_cache.get(sheet_path) as Texture2D
            if active_sheet == null and ResourceLoader.exists(sheet_path):
                active_sheet = load(sheet_path) as Texture2D
                if active_sheet != null:
                    battle_animation_cache[sheet_path] = active_sheet
        if active_sheet == null:
            continue
        var local_frame := frame_index - int(sheet_entry.get("start_frame", 0))
        var atlas := AtlasTexture.new()
        atlas.atlas = active_sheet
        atlas.region = Rect2(
            float((local_frame % columns) * frame_width),
            float(int(local_frame / columns) * frame_height),
            float(frame_width), float(frame_height))
        battle_move_animation.texture = atlas
        _apply_source_battle_frame(
            directives.get(str(frame_index + 1), {}) as Dictionary,
            source_key, player_origin, enemy_origin, animation_origin)
        await effects.apply(directives.get(str(frame_index + 1), {}) as Dictionary, frame_index + 1)
        animation_deadline += roundi(frame_time * 1000000.0)
        while preload("res://scripts/game_clock.gd").ticks_usec() < animation_deadline:
            await get_tree().process_frame
    effects.finish()
    source_effect_playing = false
    battle_move_animation.texture = null
    battle_move_animation.position = animation_origin
    player_battle_sprite.position = player_origin
    enemy_sprite.position = enemy_origin
    player_battle_sprite.scale = player_scale
    enemy_sprite.scale = enemy_scale
    player_battle_sprite.modulate = player_modulate
    enemy_sprite.modulate = enemy_modulate
    player_battle_sprite.visible = player_visible
    enemy_sprite.visible = enemy_visible
    player_hud.visible = player_hud_visible
    enemy_hud.visible = enemy_hud_visible
    source_single_hud.visible = source_hud_visible

func _source_frame_number(frame: Dictionary, key: String, fallback: float = 0.0) -> float:
    return float(frame.get(key, fallback))

func _apply_source_battle_frame(frame: Dictionary, source_key: String,
        player_origin: Vector2, enemy_origin: Vector2,
        animation_origin: Vector2) -> void:
    var actor_is_player := "_player_" in source_key
    var actor := player_battle_sprite if actor_is_player else enemy_sprite
    player_battle_sprite.position = player_origin + Vector2(
        _source_frame_number(frame, "player_translate_x"),
        -_source_frame_number(frame, "player_translate_y"))
    enemy_sprite.position = enemy_origin + Vector2(
        _source_frame_number(frame, "enemy_translate_x") +
            _source_frame_number(frame, "enemy_sprite_translate_x"),
        -_source_frame_number(frame, "enemy_translate_y") -
            _source_frame_number(frame, "enemy_sprite_translate_y"))
    if actor_is_player:
        actor.position += Vector2(
            _source_frame_number(frame, "sprite_translate_x") +
                _source_frame_number(frame, "player_sprite_translate_x"),
            _source_frame_number(frame, "sprite_translate_y") +
                _source_frame_number(frame, "player_sprite_translate_y"))
    else:
        actor.position += Vector2(
            _source_frame_number(frame, "sprite_translate_x"),
            _source_frame_number(frame, "sprite_translate_y"))
    battle_move_animation.position = animation_origin + Vector2(
        _source_frame_number(frame, "screen_translate_x"),
        _source_frame_number(frame, "screen_translate_y"))
    if battle_is_double:
        player_hud.visible = not bool(frame.get("player_healthbar_gone", false))
        enemy_hud.visible = not bool(frame.get("enemy_healthbar_gone", false))
    else:
        player_hud.visible = false
        enemy_hud.visible = false
        source_single_hud.visible = not (
            bool(frame.get("player_healthbar_gone", false)) and
            bool(frame.get("enemy_healthbar_gone", false)))
    player_battle_sprite.visible = not (
        bool(frame.get("player_sprite_gone", false)) or
        bool(frame.get("player_sprite_hide", false)))
    enemy_sprite.visible = not (
        bool(frame.get("enemy_sprite_gone", false)) or
        bool(frame.get("enemy_sprite_hide", false)))
    if bool(frame.get("player_sprite_show", false)):
        player_battle_sprite.visible = true
    if bool(frame.get("enemy_sprite_show", false)):
        enemy_sprite.visible = true
    player_battle_sprite.scale = Vector2(0.5, 0.5) if bool(
        frame.get("player_shrink", false)) else Vector2.ONE
    enemy_sprite.scale = Vector2(0.5, 0.5) if bool(
        frame.get("enemy_shrink", false)) else Vector2.ONE
    player_battle_sprite.modulate = Color(0.68, 0.68, 0.68, 1.0) if bool(
        frame.get("sprite_greyscale", false)) and actor_is_player else Color.WHITE
    enemy_sprite.modulate = Color(0.68, 0.68, 0.68, 1.0) if bool(
        frame.get("sprite_greyscale", false)) and not actor_is_player else Color.WHITE
    if bool(frame.get("user_cry", false)):
        _play_pokemon_cry(battle_player if actor_is_player else battle_enemy)

func _battle_source_key(normalized_move: String, side: String) -> String:
    if normalized_move == "curse":
        var attacker: Dictionary = battle_player if side == "player" else battle_enemy
        if "GHOST" in attacker.get("types", []): normalized_move = "curse_ghost"
    var animations: Dictionary = battle_animation_manifest.get("animations", {})
    var exact := "%s_%s_gsc" % [normalized_move, side]
    if animations.has(exact):
        return exact
    # Only spelling differences; never substitute another move's animation.
    var aliases := {"feint_attack":"faint_attack", "ancient_power":"ancientpower"}
    var aliased := String(aliases.get(normalized_move, normalized_move))
    var alias_key := "%s_%s_gsc" % [aliased, side]
    if animations.has(alias_key):
        return alias_key
    return exact

func _play_generic_battle_animation(player_attacks: bool, damaging: bool) -> void:
    var attacker_sprite := player_battle_sprite if player_attacks else enemy_sprite
    var target_sprite := enemy_sprite if player_attacks else player_battle_sprite
    if not damaging:
        var pulse := create_tween()
        pulse.tween_property(attacker_sprite, "modulate", Color(1.45, 1.45, 1.45, 1), 0.08)
        pulse.tween_property(attacker_sprite, "modulate", Color.WHITE, 0.11)
        await pulse.finished
        return
    var origin := attacker_sprite.position
    var direction := Vector2(10.0, -2.0) if player_attacks else Vector2(-10.0, 2.0)
    target_sprite.modulate = Color(1.0, 0.45, 0.45, 1.0)
    var lunge := create_tween()
    lunge.tween_property(attacker_sprite, "position", origin + direction, 0.08)
    lunge.tween_property(attacker_sprite, "position", origin, 0.10)
    await lunge.finished
    target_sprite.modulate = Color.WHITE

func _play_source_capture_poof() -> void:
    if not GameOptions.enabled("battle_animations"):
        return
    var poof: TextureRect = TextureRect.new()
    poof.name = "SourceCapturePoof"
    poof.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    poof.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    poof.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    poof.size = Vector2(48, 48)
    poof.position = enemy_sprite.position + enemy_sprite.size * 0.5 - Vector2(24, 24)
    poof.mouse_filter = Control.MOUSE_FILTER_IGNORE
    poof.z_index = 259
    battle_panel.add_child(poof)
    _play_source_battle_sound("poof1.ogg")
    for frame_index in range(5):
        var frame: AtlasTexture = AtlasTexture.new()
        frame.atlas = SOURCE_CAPTURE_POOF
        frame.region = Rect2(frame_index * 48, 0, 48, 48)
        poof.texture = frame
        await get_tree().create_timer(4.0 * SOURCE_FRAME_TIME).timeout
    poof.queue_free()

func _play_source_throw_animation(captured: bool, shakes: int = 3) -> void:
    _clear_battle_capture_ball()
    if not GameOptions.enabled("battle_animations"):
        enemy_sprite.visible = not captured
        return
    battle_capture_ball = TextureRect.new()
    battle_capture_ball.name = "SourcePokeBall"
    battle_capture_ball.texture = _battle_ball_art(SOURCE_POKEBALL_TEXTURE)
    battle_capture_ball.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    battle_capture_ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    battle_capture_ball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    battle_capture_ball.size = Vector2(24.0, 24.0)
    battle_capture_ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
    battle_capture_ball.z_index = 260
    battle_panel.add_child(battle_capture_ball)
    var start = player_battle_sprite.position + Vector2(
        player_battle_sprite.size.x * 0.72, player_battle_sprite.size.y * 0.35)
    var target = enemy_sprite.position + enemy_sprite.size * 0.5 - Vector2(12.0, 12.0)
    battle_capture_ball.position = start
    var midpoint = start.lerp(target, 0.5) + Vector2(0.0, -34.0)
    var throw_tween = create_tween()
    throw_tween.tween_property(battle_capture_ball, "position", midpoint, 0.16)
    throw_tween.tween_property(battle_capture_ball, "position", target, 0.18)
    await throw_tween.finished
    await _play_source_capture_poof()
    enemy_sprite.visible = false
    for wiggle in range(shakes):
        var frame = AtlasTexture.new()
        frame.atlas = _battle_ball_art(SOURCE_POKEBALL_WIGGLE_TEXTURE)
        frame.region = Rect2(float(wiggle * 12), 0.0, 12.0, 12.0)
        battle_capture_ball.texture = frame
        _play_source_battle_sound("pokeball_wiggle1.ogg")
        await get_tree().create_timer(43.0 * SOURCE_FRAME_TIME).timeout
    if not captured:
        _clear_battle_capture_ball()
        await _play_source_capture_poof()
        enemy_sprite.visible = true

var battle_ball_art: Dictionary = {}

## The thrown ball in the colours of the ball that was actually used. The
## field already recolours the shell this way; battle always showed a POKE BALL.
func _battle_ball_art(source: Texture2D) -> Texture2D:
    if last_battle_ball.is_empty() or last_battle_ball == "POKE BALL":
        return source
    var key := source.resource_path + "|" + last_battle_ball
    if not battle_ball_art.has(key):
        battle_ball_art[key] = ImageTexture.create_from_image(
            preload("res://scripts/ball_shell_colors.gd").recolor(source.get_image(), last_battle_ball))
    return battle_ball_art[key]

func _clear_battle_capture_ball() -> void:
    if battle_capture_ball != null and is_instance_valid(battle_capture_ball):
        battle_capture_ball.queue_free()
    battle_capture_ball = null

func _set_double_battle_layout() -> void:
    player_partner_sprite.visible = battle_is_double and not battle_player_partner.is_empty()
    enemy_partner_sprite.visible = battle_is_double and not battle_enemy_partner.is_empty()
    double_status.visible = battle_is_double
    if battle_is_double:
        player_battle_sprite.position = Vector2(18.0, 46.0)
        player_battle_sprite.size = Vector2(70.0, 68.0)
        enemy_sprite.position = Vector2(232.0, 4.0)
        enemy_sprite.size = Vector2(62.0, 54.0)
    else:
        # Spread the two sprites into the added 16:9 side space while keeping
        # each sprite's aspect ratio intact.
        # The back sprite stands on the text box, whose top edge is at 123.
        # It used to stop seven pixels short, leaving a strip of background
        # under every Pokemon drawn to be cut off by the box.
        player_battle_sprite.position = Vector2(26.0, 41.0)
        player_battle_sprite.size = Vector2(84.0, 82.0)
        enemy_sprite.position = Vector2(210.0, 2.0)
        enemy_sprite.size = Vector2(82.0, 64.0)

func _refresh_battle_sprites() -> void:
    if battle_player.is_empty() or battle_enemy.is_empty():
        return
    var player_texture := PokemonData.record_texture(battle_player, "back")
    var player_uses_front := player_texture == null
    if player_uses_front:
        player_texture = PokemonData.record_texture(battle_player, "front")
    player_battle_sprite.texture = (
        _battle_sprite_frame_at(player_texture, battle_sprite_animation_frame)
    )
    if battle_active and not bool(battle_context.get("pvp",false)):
        if not bool(battle_context.get("requires_silph_scope", false)) or bool(battle_context.get("ghost_revealed", false)):
            pokedex_progress.mark(battle_enemy)
            if battle_is_double: pokedex_progress.mark(battle_enemy_partner)
    var enemy_texture := PokemonData.record_texture(battle_enemy, "front")
    if enemy_texture == null:
        enemy_texture = POKEMON_TEXTURES.get(String(battle_enemy.species)) as Texture2D
    var ghost_hidden := String(battle_context.get("kind", "")) == "ghost" and \
        not bool(battle_context.get("ghost_revealed", true))
    if ghost_hidden:
        enemy_texture = _ghost_battle_texture()
    enemy_sprite.texture = (
        _battle_sprite_frame(enemy_texture) if ghost_hidden or String(battle_enemy.get("species","")) == "mew"
        else _battle_sprite_frame_at(enemy_texture, battle_sprite_animation_frame)
    )
    if is_instance_valid(source_boss):
        enemy_sprite.texture=source_boss.body
    if is_instance_valid(source_mewtwo):
        enemy_sprite.texture = source_mewtwo.body
    if battle_is_double:
        if not battle_player_partner.is_empty():
            var ally_texture := PokemonData.record_texture(battle_player_partner, "back")
            var ally_uses_front := ally_texture == null
            if ally_uses_front:
                ally_texture = PokemonData.record_texture(battle_player_partner, "front")
            player_partner_sprite.texture = (
                _battle_sprite_frame_at(ally_texture, battle_sprite_animation_frame)
            )
        if not battle_enemy_partner.is_empty():
            var foe_texture := PokemonData.record_texture(battle_enemy_partner, "front")
            if foe_texture == null:
                foe_texture = POKEMON_TEXTURES.get(String(battle_enemy_partner.species)) as Texture2D
            enemy_partner_sprite.texture = _battle_sprite_frame_at(
                foe_texture, battle_sprite_animation_frame)
        player_partner_sprite.visible = not battle_player_partner.is_empty() and \
            int(battle_player_partner.get("hp", 0)) > 0
        enemy_partner_sprite.visible = not battle_enemy_partner.is_empty() and \
            int(battle_enemy_partner.get("hp", 0)) > 0

func _update_battle_hud() -> void:
    if battle_player.is_empty() or battle_enemy.is_empty():
        return
    var enemy_status = String(battle_enemy.get("status", ""))
    if not enemy_status.is_empty():
        enemy_status = " " + enemy_status.left(3)
    var player_status = String(battle_player.get("status", ""))
    if not player_status.is_empty():
        player_status = " " + player_status.left(3)
    var enemy_display_name = PokemonState.battle_display_name(battle_enemy).to_upper()
    if String(battle_context.get("kind", "")) == "ghost" and not bool(battle_context.get("ghost_revealed", true)):
        enemy_display_name = "GHOST"
    enemy_label.text = "%s  LV %d%s" % [
        enemy_display_name.left(10),
        int(battle_enemy.level), enemy_status
    ]
    enemy_level_label.text = ""
    enemy_gender_label.text = "" if bool(battle_enemy.get("is_ghost", false)) else _gender_symbol(battle_enemy)
    player_battle_label.text = "%s  LV %d%s" % [
        PokemonState.battle_display_name(battle_player).to_upper().left(9),
        int(battle_player.level), player_status
    ]
    player_level_label.text = ""
    player_gender_label.text = _gender_symbol(battle_player)
    _set_fitting_pokemon_name(source_enemy_name, battle_enemy, enemy_display_name)
    _fit_source_battle_level(source_enemy_level, source_enemy_gender, "EnemyLevelChar", int(battle_enemy.level))
    source_enemy_status.text = _battle_status_abbreviation(battle_enemy)
    _size_battle_status_label(source_enemy_status, battle_enemy, 11.0)
    _set_source_gender(source_enemy_gender, battle_enemy)
    if bool(battle_enemy.get("is_ghost", false)): source_enemy_gender.visible = false
    _set_fitting_pokemon_name(source_player_name, battle_player)
    _fit_source_battle_level(source_player_level, source_player_gender, "PlayerLevelChar", int(battle_player.level))
    source_player_status.text = _battle_status_abbreviation(battle_player)
    _size_battle_status_label(source_player_status, battle_player, 63.0)
    _set_source_gender(source_player_gender, battle_player)
    var enemy_ratio = clampf(
        float(battle_enemy.hp) / maxf(1.0, float(battle_enemy.max_hp)), 0.0, 1.0)
    var player_ratio = clampf(
        float(battle_player.hp) / maxf(1.0, float(battle_player.max_hp)), 0.0, 1.0)
    enemy_hp_fill.size.x = _battle_hp_width(enemy_ratio, 106.0)
    player_hp_fill.size.x = _battle_hp_width(player_ratio, 110.0)
    enemy_hp_fill.color = _battle_hp_color(enemy_ratio)
    player_hp_fill.color = _battle_hp_color(player_ratio)
    player_hp_value.text = "%d/ %d" % [int(battle_player.hp), int(battle_player.max_hp)]
    source_enemy_hp_fill.size.x = _battle_hp_width(enemy_ratio, 48.0)
    source_player_hp_fill.size.x = _battle_hp_width(player_ratio, 48.0)
    source_enemy_hp_fill.color = _battle_hp_color(enemy_ratio)
    source_player_hp_fill.color = _battle_hp_color(player_ratio)
    source_player_hp_current.text = str(int(battle_player.hp))
    source_player_hp_max.text = str(int(battle_player.max_hp))
    var player_level = int(battle_player.get("level", 1))
    var exp_ratio = 1.0
    if player_level < 100:
        var exp_floor = BattleEngine.exp_for_level(
            String(battle_player.get("species", "machop")), player_level)
        var exp_ceiling = BattleEngine.exp_for_level(
            String(battle_player.get("species", "machop")), player_level + 1)
        exp_ratio = clampf(float(int(battle_player.get("exp", exp_floor)) - exp_floor) /
            maxf(1.0, float(exp_ceiling - exp_floor)), 0.0, 1.0)
    _set_player_exp_bar_ratio(exp_ratio)
    if battle_is_double:
        var ally_text = "NO ALLY"
        var foe_text = "NO FOE"
        if not battle_player_partner.is_empty():
            ally_text = "%s %d/%d" % [PokemonState.battle_display_name(battle_player_partner).to_upper().left(9),
                int(battle_player_partner.hp), int(battle_player_partner.max_hp)]
        if not battle_enemy_partner.is_empty():
            foe_text = "%s %d/%d" % [PokemonState.battle_display_name(battle_enemy_partner).to_upper().left(9),
                int(battle_enemy_partner.hp), int(battle_enemy_partner.max_hp)]
        double_status.text = "%s     FOE: %s" % [ally_text, foe_text]
    var terrain_name = String(battle_field.get("terrain", "GRASSY")).replace("_", " ")
    var weather_name = String(battle_field.get("weather", ""))
    battle_field_label.text = "%s FIELD" % terrain_name
    if not weather_name.is_empty():
        battle_field_label.text += " / %s %d" % [weather_name,
            int(battle_field.get("weather_turns", 0))]

func _size_battle_status_label(label: Label, pokemon: Dictionary, base_y: float) -> void:
    var compact := String(pokemon.get("status", "")).to_upper() in ["SLEEP", "POISON", "TOXIC", "PARALYSIS"]
    label.add_theme_font_size_override("font_size", 9 if compact else 10)
    label.position.y = base_y - (1.0 if compact else 0.0)

func _battle_status_abbreviation(pokemon: Dictionary) -> String:
    return {
        "BURN":"BRN", "POISON":"PSN", "TOXIC":"PSN",
        "PARALYSIS":"PAR", "SLEEP":"SLP", "FREEZE":"FRZ"
    }.get(String(pokemon.get("status", "")).to_upper(), "")

func _resolved_battle_gender(pokemon: Dictionary) -> String:
    var species: String = String(pokemon.get("species", "")).to_lower()
    if species in ["nidoran_f", "nidoran-f", "nidoran♀"]:
        return "female"
    if species in ["nidoran_m", "nidoran-m", "nidoran♂"]:
        return "male"
    return String(pokemon.get("gender", "")).to_lower()

func _gender_symbol(pokemon: Dictionary) -> String:
    var gender: String = _resolved_battle_gender(pokemon)
    if gender in ["female", "f", "♀"]:
        return "♀"
    if gender in ["male", "m", "♂"]:
        return "♂"
    return ""

func _fit_source_battle_level(label: Label, gender: Control, prefix_name: String, level: int) -> void:
    var prefix := source_single_hud.get_node(prefix_name) as Control
    if not label.has_meta("level_origin_x"):
        label.set_meta("level_origin_x", label.position.x)
        prefix.set_meta("level_origin_x", prefix.position.x)
    label.text = str(level)
    var width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
    var original: float = label.get_meta("level_origin_x")
    var shift := minf(0.0, gender.position.x - 2.0 - original - width) if level >= 100 else 0.0
    label.position.x = original + shift
    prefix.position.x = float(prefix.get_meta("level_origin_x")) + shift

func _set_source_gender(target: TextureRect, pokemon: Dictionary) -> void:
    var gender: String = _resolved_battle_gender(pokemon)
    target.visible = gender in ["female", "f", "♀", "male", "m", "♂"]
    if gender in ["female", "f", "♀"]:
        target.texture = SOURCE_FEMALE_SYMBOL
    elif target.visible:
        target.texture = SOURCE_MALE_SYMBOL

func _play_level_up_sound() -> void:
    if ResourceLoader.exists(LEVEL_UP_AUDIO_PATH):
        battle_audio.stream = load(LEVEL_UP_AUDIO_PATH) as AudioStream
        AudioBalance.apply(battle_audio)
        battle_audio.play()

func _play_source_battle_feedback_audio(key: String) -> void:
    var path := String((battle_animation_manifest.get("audio",{}) as Dictionary).get(key,""))
    if not path.is_empty() and ResourceLoader.exists(path):
        battle_audio.stream=load(path)
        AudioBalance.apply(battle_audio)
        battle_audio.play()

func _play_source_battle_sound(filename: String) -> void:
    var normalized := filename
    if not normalized.to_lower().ends_with(".ogg"):
        normalized += ".ogg"
    var path := SOURCE_SOUND_ROOT + normalized
    if ResourceLoader.exists(path):
        battle_audio.stream = load(path) as AudioStream
        AudioBalance.apply(battle_audio)
        battle_audio.play()

func _play_pokemon_cry(pokemon: Dictionary, gain: float = 1.0) -> void:
    if pokemon.is_empty():
        return
    var cry_path := "res://assets/source_audio/cries/000.ogg" if bool(pokemon.get("is_ghost", false)) else PokemonData.cry_path(String(pokemon.get("species", "")))
    if cry_path.is_empty() or not ResourceLoader.exists(cry_path):
        return
    battle_audio.stream = load(cry_path) as AudioStream
    AudioBalance.apply(battle_audio)
    battle_audio.volume_db += linear_to_db(maxf(gain, 0.001))
    battle_audio.play()

func _battle_hp_color(ratio: float) -> Color:
    if ratio <= 0.20:
        return Color8(248, 0, 0, 255)
    if ratio <= 0.50:
        return Color8(248, 184, 0, 255)
    return Color8(0, 184, 0, 255)

func _battle_hp_width(ratio: float, maximum_width: float) -> float:
    if ratio <= 0.0:
        return 0.0
    return maxf(1.0, roundf(maximum_width * ratio))

func _set_animated_battle_hp(pokemon: Dictionary, displayed_hp: int,
        player_side: bool) -> void:
    var maximum := maxi(1, int(pokemon.get("max_hp", 1)))
    var ratio := clampf(float(displayed_hp) / float(maximum), 0.0, 1.0)
    if player_side:
        player_hp_fill.size.x = _battle_hp_width(ratio, 110.0)
        player_hp_fill.color = _battle_hp_color(ratio)
        player_hp_value.text = "%d/ %d" % [displayed_hp, maximum]
        source_player_hp_fill.size.x = _battle_hp_width(ratio, 48.0)
        source_player_hp_fill.color = _battle_hp_color(ratio)
        source_player_hp_current.text = str(displayed_hp)
        source_player_hp_max.text = str(maximum)
    else:
        enemy_hp_fill.size.x = _battle_hp_width(ratio, 106.0)
        enemy_hp_fill.color = _battle_hp_color(ratio)
        source_enemy_hp_fill.size.x = _battle_hp_width(ratio, 48.0)
        source_enemy_hp_fill.color = _battle_hp_color(ratio)

func _animate_battle_hp_change(pokemon: Dictionary, from_hp: int,
        to_hp: int, player_side: bool) -> void:
    if from_hp == to_hp:
        return
    var maximum := maxi(1, int(pokemon.get("max_hp", 1)))
    var start_width := roundi(48.0 * float(from_hp) / float(maximum))
    var end_width := roundi(48.0 * float(to_hp) / float(maximum))
    var frames := maxi(1, absi(start_width - end_width))
    var hp_start := preload("res://scripts/game_clock.gd").ticks_usec()
    for frame_index in range(1, frames + 1):
        var shown_hp := roundi(lerpf(float(from_hp), float(to_hp),
            float(frame_index) / float(frames)))
        _set_animated_battle_hp(pokemon, shown_hp, player_side)
        var deadline := hp_start + int(frame_index * SOURCE_FRAME_TIME * 1000000.0)
        while preload("res://scripts/game_clock.gd").ticks_usec() < deadline:
            await get_tree().process_frame

func _animate_visible_battle_hp(pokemon: Dictionary, from_hp: int,
        to_hp: int) -> void:
    if is_same(pokemon, battle_player):
        await _animate_battle_hp_change(pokemon, from_hp, to_hp, true)
    elif is_same(pokemon, battle_enemy):
        await _animate_battle_hp_change(pokemon, from_hp, to_hp, false)

func _update_battle_field_visuals() -> void:
    var color := Color(0.18, 0.55, 0.18, 0.06)
    match String(battle_field.get("terrain", "GRASSY")):
        "AQUATIC": color = Color(0.18, 0.38, 0.82, 0.09)
        "SANDY": color = Color(0.72, 0.55, 0.22, 0.10)
    match String(battle_field.get("weather", "")):
        "RAIN": color = Color(0.12, 0.30, 0.75, 0.19)
        "SUN": color = Color(1.0, 0.72, 0.15, 0.15)
        "SANDSTORM": color = Color(0.65, 0.48, 0.20, 0.21)
    battle_weather_overlay.color = color
    _update_battle_hud()

func _show_message(message: String) -> void:
    if trainer_tip_open:
        _close_trainer_tip()
    # Active field moves must not paint control instructions across the bottom
    # dialogue area. Keep actual results/errors, but suppress selection/control
    # hints because the dedicated field/build UI already carries the state.
    var active_move := String(world.get("active_field_move")).to_upper()
    if not active_move.is_empty():
        if message.begins_with("BUILD:") or message.begins_with("DIG:") or \
                message.begins_with("PAINT:") or "L/R selects" in message or \
                message.begins_with("FLY is active.") or \
                message.begins_with("Fly to safe ground") or \
                message.begins_with("SURF lets you cross water") or \
                message.begins_with("RIDE increases speed"):
            return
    if build_menu_open and message.begins_with("BUILD:"):
        return
    message_label.add_theme_font_override("font", JOHTO_FONT)
    message_label.add_theme_font_size_override("font_size", 10)
    message_label.clip_text = true
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.max_lines_visible = 3
    message_label.text = message
    message_label.visible_characters = 0
    message_reveal_elapsed = 0.0
    message_reveal_text = message
    message_panel.visible = true
    message_timer = MESSAGE_HOLD_SECONDS + message.length() * BATTLE_TEXT_CHAR_DELAY / GameOptions.text_multiplier()


func _show_unown_message(message: String) -> void:
    if trainer_tip_open:
        _close_trainer_tip()
    message_label.add_theme_font_override("font", UNOWN_FONT)
    message_label.add_theme_font_size_override("font_size", 9)
    message_label.clip_text = true
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.max_lines_visible = 3
    message_label.text = message
    message_panel.visible = true
    message_timer = 1.2

func _trainer_tip_wrap_lines(message: String, max_chars: int = 39) -> Array[String]:
    var result: Array[String] = []
    for paragraph in message.split("\n"):
        var current := ""
        for raw_word in String(paragraph).split(" ", false):
            var word := String(raw_word)
            var candidate := word if current.is_empty() else current + " " + word
            if candidate.length() <= max_chars:
                current = candidate
            else:
                if not current.is_empty():
                    result.append(current)
                current = word
        if not current.is_empty():
            result.append(current)
    if result.is_empty():
        result.append("")
    return result


func _show_trainer_tip_message(message: String) -> void:
    trainer_tip_pages.clear()
    var lines := _trainer_tip_wrap_lines(message)
    var index := 0
    while index < lines.size():
        var page_lines: Array[String] = []
        page_lines.append(lines[index])
        if index + 1 < lines.size():
            page_lines.append(lines[index + 1])
        trainer_tip_pages.append("\n".join(page_lines))
        index += 2
    trainer_tip_page_index = 0
    trainer_tip_open = true
    world.set_gameplay_enabled(false)
    _show_trainer_tip_page()


func _show_trainer_tip_page() -> void:
    if trainer_tip_pages.is_empty():
        _close_trainer_tip()
        return
    message_label.add_theme_font_override("font", JOHTO_FONT)
    message_label.add_theme_font_size_override("font_size", 8)
    message_label.clip_text = true
    message_label.autowrap_mode = TextServer.AUTOWRAP_OFF
    message_label.max_lines_visible = 2
    message_label.text = trainer_tip_pages[trainer_tip_page_index]
    message_panel.visible = true
    message_timer = 0.0
    if trainer_tip_continue != null:
        trainer_tip_continue.visible = (
            trainer_tip_page_index < trainer_tip_pages.size() - 1
        )


func _advance_trainer_tip() -> void:
    if not trainer_tip_open:
        return
    if trainer_tip_page_index < trainer_tip_pages.size() - 1:
        trainer_tip_page_index += 1
        _show_trainer_tip_page()
        return
    _close_trainer_tip()


func _close_trainer_tip() -> void:
    trainer_tip_open = false
    trainer_tip_pages.clear()
    trainer_tip_page_index = 0
    if trainer_tip_continue != null:
        trainer_tip_continue.visible = false
    message_panel.visible = false
    message_timer = 0.0
    if (
            started
            and not battle_active
            and not game_menu_open
            and not craft_menu_open
            and not build_menu_open
            and not storage_menu_open
        ):
        world.set_gameplay_enabled(true)

func _open_game_menu() -> void:
    if battle_active or generating or not started or \
            (field_item_busy and not _sleeping_bag_active()):
        return
    game_menu_open = true
    game_menu_detail_open = false
    pokemon_menu_open = false
    pokemon_action_open = false
    pokemon_switch_selecting = false
    pokemon_action_panel.visible = false
    guide_menu_open = false
    guide_topic_open = false
    pokemon_menu_index = 0
    save_confirm_open = false
    save_confirm_index = 0
    save_confirm.visible = false
    game_menu_index = 0
    game_menu.visible = true
    game_menu_box.visible = true
    game_menu_detail.visible = false
    game_menu_map_screen.visible = false
    item_pocket_menu.visible = false
    item_pocket_context = ""
    pokemon_menu.visible = false
    guide_menu.visible = false
    world.set_gameplay_enabled(false)
    touch_controls.set_game_active(true)
    message_panel.visible = false
    _update_game_menu_cursor()

func _close_game_menu() -> void:
    planting_bag_target = null
    game_menu_open = false
    game_menu_detail_open = false
    pokemon_menu_open = false
    pokemon_action_open = false
    pokemon_switch_selecting = false
    pokemon_switch_source_index = -1
    pokemon_action_panel.visible = false
    pokemon_stats_open = false
    pokemon_stats_overlay.visible = false
    guide_menu_open = false
    guide_topic_open = false
    save_confirm_open = false
    save_confirm.visible = false
    game_menu.visible = false
    game_menu_detail.visible = false
    item_menu_active = false
    item_pocket_context = ""
    battle_item_pocket_open = false
    item_pocket_menu.visible = false
    pokemon_menu.visible = false
    guide_menu.visible = false
    game_menu_map.visible = false
    game_menu_map_screen.visible = false
    _clear_map_canvas()
    world.set_gameplay_enabled(not _sleeping_bag_active())
    touch_controls.set_game_active(true)

func _handle_game_menu_input(event: InputEvent) -> void:
    if not overworld_evolution_item.is_empty():
        _handle_evolution_item_input(event)
        return
    if item_pocket_context == "OVERWORLD" and battle_item_pocket_open:
        _handle_overworld_item_pocket_input(event)
        return

    if guide_topic_open:
        if event.is_action_pressed("confirm") or event.is_action_pressed("cancel") or event.is_action_pressed("start"):
            guide_topic_open = false
            game_menu_detail_open = false
            game_menu_detail.visible = false
            guide_menu.visible = true
            get_viewport().set_input_as_handled()
        return

    if guide_menu_open:
        if event.is_action_pressed("move_up"):
            guide_menu_index = wrapi(guide_menu_index - 1, 0, GUIDE_TOPICS.size())
            _refresh_guide_menu()
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("move_down"):
            guide_menu_index = wrapi(guide_menu_index + 1, 0, GUIDE_TOPICS.size())
            _refresh_guide_menu()
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("confirm"):
            _show_selected_guide_topic()
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("cancel") or event.is_action_pressed("start"):
            guide_menu_open = false
            guide_menu.visible = false
            game_menu_box.visible = true
            get_viewport().set_input_as_handled()
        return

    if pokemon_menu_open:
        if pokemon_action_open:
            if event.is_action_pressed("move_up"):
                pokemon_action_index = wrapi(pokemon_action_index - 1, 0,
                    pokemon_action_entries.size())
                _refresh_pokemon_action_menu()
            elif event.is_action_pressed("move_down"):
                pokemon_action_index = wrapi(pokemon_action_index + 1, 0,
                    pokemon_action_entries.size())
                _refresh_pokemon_action_menu()
            elif event.is_action_pressed("confirm"):
                _activate_pokemon_action()
            elif event.is_action_pressed("cancel") or event.is_action_pressed("start"):
                _close_pokemon_action_menu()
            else:
                return
            get_viewport().set_input_as_handled()
            return
        if event.is_action_pressed("move_up"):
            if not caught_pokemon.is_empty():
                pokemon_menu_index = wrapi(pokemon_menu_index - 1, 0,
                    mini(6, caught_pokemon.size()))
                _refresh_pokemon_category_menu()
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("move_down"):
            if not caught_pokemon.is_empty():
                pokemon_menu_index = wrapi(pokemon_menu_index + 1, 0,
                    mini(6, caught_pokemon.size()))
                _refresh_pokemon_category_menu()
            get_viewport().set_input_as_handled()
        elif pokemon_switch_selecting and event.is_action_pressed("confirm"):
            _finish_pokemon_switch()
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("cancel") or event.is_action_pressed("start"):
            if pokemon_switch_selecting:
                pokemon_switch_selecting = false
                pokemon_switch_source_index = -1
                pokemon_menu_prompt.text = "Choose a POKEMON."
            else:
                pokemon_menu_open = false
                pokemon_menu.visible = false
                game_menu_box.visible = true
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("confirm"):
            _open_pokemon_action_menu()
            get_viewport().set_input_as_handled()
        return

    if save_confirm_open:
        if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
            save_confirm_index = 1 - save_confirm_index
            _update_save_confirm_cursor()
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("confirm"):
            if save_confirm_index == 0:
                _save_current_game()
            else:
                _close_save_confirmation()
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("cancel") or event.is_action_pressed("start"):
            _close_save_confirmation()
            get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("start") or event.is_action_pressed("cancel"):
        if game_menu_detail_open:
            item_menu_active = false
            game_menu_detail_open = false
            game_menu_detail.visible = false
            game_menu_box.visible = true
            game_menu_map.visible = false
            game_menu_map_screen.visible = false
            teleport_map_mode = false
            teleport_destinations.clear()
            _clear_map_canvas()
        else:
            _close_game_menu()
        get_viewport().set_input_as_handled()
        return

    if game_menu_detail_open:
        if game_menu_map_screen.visible:
            if teleport_map_mode:
                if event.is_action_pressed("move_left") or event.is_action_pressed("move_up") or event.is_action_pressed("shoulder_left"):
                    _cycle_teleport_destination(-1)
                    get_viewport().set_input_as_handled()
                elif event.is_action_pressed("move_right") or event.is_action_pressed("move_down") or event.is_action_pressed("shoulder_right"):
                    _cycle_teleport_destination(1)
                    get_viewport().set_input_as_handled()
                elif event.is_action_pressed("confirm"):
                    if world.has_method("teleport_to_destination"):
                        world.call("teleport_to_destination", teleport_destination_index)
                    teleport_map_mode = false
                    _close_game_menu()
                    get_viewport().set_input_as_handled()
                return
            if event.is_action_pressed("confirm") and is_instance_valid(waypoint_ui):
                waypoint_ui.begin_name()
                get_viewport().set_input_as_handled()
                return
            if GameOptions.enabled("zoom") and (event.is_action_pressed("zoom_in") or event.is_action_pressed("shoulder_right")):
                _set_map_zoom(map_zoom * 1.25)
                get_viewport().set_input_as_handled()
            elif GameOptions.enabled("zoom") and (event.is_action_pressed("zoom_out") or event.is_action_pressed("shoulder_left")):
                _set_map_zoom(map_zoom / 1.25)
                get_viewport().set_input_as_handled()
            return
        if event.is_action_pressed("confirm"):
            game_menu_detail_open = false
            game_menu_detail.visible = false
            game_menu_box.visible = true
            game_menu_map.visible = false
            game_menu_map_screen.visible = false
            _clear_map_canvas()
            get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("move_up"):
        game_menu_index = wrapi(game_menu_index - 1, 0, GAME_MENU_OPTIONS.size())
        _update_game_menu_cursor()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("move_down"):
        game_menu_index = wrapi(game_menu_index + 1, 0, GAME_MENU_OPTIONS.size())
        _update_game_menu_cursor()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("confirm"):
        _activate_game_menu_option()
        get_viewport().set_input_as_handled()

func _update_game_menu_cursor() -> void:
    var row := game_menu_box.get_node_or_null("Option%d" % game_menu_index) as Label
    if row != null: _align_menu_tick(game_menu_cursor, row)

func _activate_game_menu_option() -> void:
    var option = String(GAME_MENU_OPTIONS[game_menu_index])
    match option:
        "STORAGE":
            _open_pooled_storage_menu()
        "POKEMON":
            _show_pokemon_menu()
        "ITEM":
            _show_item_menu()
        "MAP":
            _show_map_menu()
        "POKEDEX":
            pokedex_menu.open(true)
        "GUIDE":
            _show_guide_menu()
        "OPTIONS":
            options_menu.open()
        "SAVE":
            _open_save_confirmation()
        "EXIT":
            _close_game_menu()
            _open_quit_prompt()

func _open_detail(title: String, body: String) -> void:
    game_menu_detail_open = true
    game_menu_box.visible = false
    game_menu_detail.visible = true
    game_menu_detail_title.text = title
    game_menu_detail_body.text = body
    game_menu_map.visible = false
    game_menu_map_screen.visible = false

func _show_pokemon_menu() -> void:
    pokemon_menu_open = true
    pokemon_menu_index = 0
    pokemon_move_index = 0
    pokemon_action_open = false
    pokemon_switch_selecting = false
    pokemon_action_panel.visible = false
    game_menu_box.visible = false
    game_menu_detail.visible = false
    game_menu_map.visible = false
    game_menu_map_screen.visible = false
    pokemon_menu.visible = true
    _refresh_pokemon_category_menu()

func _refresh_pokemon_category_menu() -> void:
    pokemon_menu_prompt.text = "Choose a POKEMON."

    if caught_pokemon.is_empty():
        _refresh_party_list_rows(pokemon_party_rows, [], -1)
        pokemon_menu_prompt.text = "NO POKEMON.   B: BACK"
        return

    var visible_count := mini(6, caught_pokemon.size())
    pokemon_menu_index = clampi(pokemon_menu_index, 0, visible_count - 1)
    for index in range(visible_count):
        if typeof(caught_pokemon[index]) == TYPE_DICTIONARY:
            caught_pokemon[index] = BattleEngine.ensure_pokemon(
                caught_pokemon[index] as Dictionary)
    _refresh_party_list_rows(pokemon_party_rows, caught_pokemon,
        pokemon_menu_index)
    var entry := caught_pokemon[pokemon_menu_index] as Dictionary
    if bool(entry.get("is_egg", false)):
        pokemon_menu_prompt.text = "%d STEPS TO HATCH   B: BACK" % int(
            entry.get("hatch_steps", EGG_HATCH_STEPS))
        return
    pokemon_menu_prompt.text = (
        "Move to which position?" if pokemon_switch_selecting
        else "Choose a POKEMON."
    )

func _pokemon_world_actions(species: String, pokemon: Dictionary = {}) -> Array[String]:
    if bool(pokemon.get("is_egg", false)): return ["SWITCH", "DROP", "CANCEL"]
    var result := FieldMoveData.field_moves_for(species, String(pokemon.get("form", "")))
    if not result.has("FOLLOW"):
        result.append("FOLLOW")
    result.append("STATS")
    result.append("SWITCH")
    result.append("DROP")
    result.append("CANCEL")
    return result

func _open_pokemon_action_menu() -> void:
    if caught_pokemon.is_empty():
        return
    var entry := caught_pokemon[pokemon_menu_index] as Dictionary
    pokemon_action_entries = _pokemon_world_actions(
        String(entry.get("species", "")), entry)
    pokemon_action_index = 0
    pokemon_action_open = true
    pokemon_action_panel.visible = true
    _refresh_pokemon_action_menu()

func _refresh_pokemon_action_menu() -> void:
    if pokemon_action_entries.is_empty():
        pokemon_action_entries = ["CANCEL"]
    pokemon_action_index = wrapi(pokemon_action_index, 0, pokemon_action_entries.size())
    _refresh_source_action_rows(pokemon_action_list, pokemon_action_cursor,
        pokemon_action_entries, pokemon_action_index)

func _close_pokemon_action_menu() -> void:
    pokemon_action_open = false
    pokemon_action_panel.visible = false

func _activate_pokemon_action() -> void:
    if pokemon_action_entries.is_empty():
        return
    var action := String(pokemon_action_entries[pokemon_action_index])
    if action == "CANCEL":
        _close_pokemon_action_menu()
        return
    if action == "STATS":
        var selected := BattleEngine.ensure_pokemon(caught_pokemon[pokemon_menu_index])
        caught_pokemon[pokemon_menu_index] = selected
        _close_pokemon_action_menu()
        _open_pokemon_stats(selected, "OVERWORLD")
        return
    if action == "SWITCH":
        _close_pokemon_action_menu()
        pokemon_switch_selecting = true
        pokemon_switch_source_index = pokemon_menu_index
        pokemon_menu_prompt.text = "Move to which position?"
        return
    if action == "DROP":
        _close_pokemon_action_menu()
        _deploy_selected_pokemon()
        return
    pokemon_move_index = pokemon_action_entries.find(action)
    _close_pokemon_action_menu()
    _activate_selected_field_move()

func _finish_pokemon_switch() -> void:
    if caught_pokemon.is_empty():
        return
    var destination := pokemon_menu_index
    var source_index := clampi(pokemon_switch_source_index, 0,
        caught_pokemon.size() - 1)
    if source_index != destination:
        var source_pokemon = caught_pokemon[source_index]
        caught_pokemon[source_index] = caught_pokemon[destination]
        caught_pokemon[destination] = source_pokemon
    pokemon_switch_selecting = false
    pokemon_switch_source_index = -1
    pokemon_menu_index = destination
    _refresh_pokemon_category_menu()

func _open_pokemon_stats(pokemon: Dictionary, return_context: String) -> void:
    pokemon_stats_pokemon = BattleEngine.ensure_pokemon(pokemon)
    pokemon_stats_return_context = return_context
    pokemon_stats_page = 0
    pokemon_stats_open = true
    pokemon_stats_overlay.visible = true
    _refresh_pokemon_stats()

func _refresh_pokemon_stats() -> void:
    if pokemon_stats_pokemon.is_empty():
        return
    var pokemon = pokemon_stats_pokemon
    var species = String(pokemon.get("species", "machop")).to_lower()
    var info = PokemonData.info(species)
    var stats = pokemon.get("stats", {}) as Dictionary
    var level = int(pokemon.get("level", 1))
    pokemon_stats_background.texture = SOURCE_STATS_BACKGROUNDS[pokemon_stats_page]
    pokemon_stats_sprite.texture = _battle_sprite_frame(PokemonData.record_texture(pokemon, "front"))
    pokemon_stats_header_left.text = "No.%03d" % int(info.get("dex", 0))
    pokemon_stats_header_right.text = ":L%d" % level
    var level_width := pokemon_stats_header_right.get_theme_font("font").get_string_size(pokemon_stats_header_right.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
    pokemon_stats_header_right.size.x = maxf(48.0, level_width)
    pokemon_stats_header_right.position.x = 276.0 - pokemon_stats_header_right.size.x
    pokemon_stats_shiny.visible = PokemonData.is_shiny(pokemon)
    _set_fitting_pokemon_name(pokemon_stats_fields.Name as Label, pokemon)
    _set_source_gender(pokemon_stats_gender, pokemon)
    for index in range(3):
        pokemon_stats_pages[index].visible = index == pokemon_stats_page
        pokemon_stats_tab_ticks[index].visible = index == pokemon_stats_page
        pokemon_stats_tabs[index].color = [Color8(248, 152, 248),
            Color8(176, 248, 104), Color8(136, 240, 240)][index]
    var hp = int(pokemon.get("hp", 0))
    var max_hp = maxi(1, int(pokemon.get("max_hp", 1)))
    (pokemon_stats_fields.HP as Label).text = "%d/%d" % [hp, max_hp]
    var status = String(pokemon.get("status", ""))
    (pokemon_stats_fields.Status as Label).text = "OK" if status.is_empty() else status
    (pokemon_stats_fields.Types as Label).text = "\n".join(info.get("types", ["NORMAL"]))
    var current_exp = int(pokemon.get("exp", BattleEngine.exp_for_level(species, level)))
    var next_exp = BattleEngine.exp_for_level(species, mini(100, level + 1))
    (pokemon_stats_fields.Exp as Label).text = str(current_exp)
    (pokemon_stats_fields.NextExp as Label).text = str(maxi(0, next_exp - current_exp))
    (pokemon_stats_fields.NextLevel as Label).text = "TO :L%d" % mini(100, level + 1)
    var exp_floor = BattleEngine.exp_for_level(species, level)
    var exp_ratio = 1.0 if level >= 100 else clampf(
        float(current_exp - exp_floor) / maxf(1.0, float(next_exp - exp_floor)), 0.0, 1.0)
    if pokemon_stats_exp_fill != null:
        pokemon_stats_exp_fill.size.x = floorf(126.0 * exp_ratio)
    var held = String(pokemon.get("held_item", ""))
    (pokemon_stats_fields.Item as Label).text = "---" if held.is_empty() else held
    var moves: Array = pokemon.get("moves", [])
    for index in range(4):
        (pokemon_stats_fields["Move%d" % index] as Label).text = (
            String(moves[index]).replace("_", " ") if index < moves.size() else "-")
    (pokemon_stats_fields.TrainerId as Label).text = "%05d" % int(pokemon.get("trainer_id", 0))
    (pokemon_stats_fields.OriginalTrainer as Label).text = String(
        pokemon.get("original_trainer", player_model_name.text)).to_upper().left(9)
    for key in ["attack", "defense", "sp_attack", "sp_defense", "speed"]:
        (pokemon_stats_fields[key] as Label).text = str(int(stats.get(key, 0)))

func _handle_pokemon_stats_input(event: InputEvent) -> void:
    if event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
        pokemon_stats_page = wrapi(pokemon_stats_page - 1, 0, 3)
        _refresh_pokemon_stats()
    elif event.is_action_pressed("move_right") or event.is_action_pressed("move_down") or \
            event.is_action_pressed("confirm"):
        pokemon_stats_page = wrapi(pokemon_stats_page + 1, 0, 3)
        _refresh_pokemon_stats()
    elif event.is_action_pressed("cancel") or event.is_action_pressed("start"):
        _close_pokemon_stats()
    else:
        return
    get_viewport().set_input_as_handled()

func _close_pokemon_stats() -> void:
    pokemon_stats_open = false
    pokemon_stats_overlay.visible = false
    if pokemon_stats_return_context == "OVERWORLD" and pokemon_menu_open:
        pokemon_action_open = true
        pokemon_action_panel.visible = true
    elif pokemon_stats_return_context == "BATTLE" and battle_active and \
            battle_submenu_mode == "PARTY":
        battle_party_action_open = true
        battle_party_action_panel.visible = true
    pokemon_stats_return_context = ""
    pokemon_stats_pokemon = {}

func _cycle_selected_field_move(direction: int) -> void:
    if caught_pokemon.is_empty():
        return
    var entry = caught_pokemon[clampi(pokemon_menu_index, 0, caught_pokemon.size() - 1)]
    if typeof(entry) != TYPE_DICTIONARY:
        return
    if bool((entry as Dictionary).get("is_egg", false)):
        return
    var moves := _pokemon_world_actions(String(entry.get("species", "")), entry)
    pokemon_move_index = wrapi(pokemon_move_index + direction, 0, moves.size())
    _refresh_pokemon_category_menu()

func _activate_selected_field_move() -> void:
    if caught_pokemon.is_empty():
        return
    pokemon_menu_index = clampi(pokemon_menu_index, 0, caught_pokemon.size() - 1)
    _ensure_party_ecology_id(pokemon_menu_index)
    var entry = caught_pokemon[pokemon_menu_index]
    if typeof(entry) != TYPE_DICTIONARY:
        return
    if bool((entry as Dictionary).get("is_egg", false)):
        _show_message("An EGG has no field move.")
        return
    if int((entry as Dictionary).get("hp", 1)) <= 0:
        _show_message("A fainted POKEMON cannot use a FIELD MOVE.")
        return
    var species := String(entry.get("species", "")).to_lower()
    var moves := _pokemon_world_actions(species, entry)
    pokemon_move_index = clampi(pokemon_move_index, 0, moves.size() - 1)
    var move := String(moves[pokemon_move_index])
    if move == "STATS":
        var pokemon := BattleEngine.ensure_pokemon(entry)
        caught_pokemon[pokemon_menu_index] = pokemon
        _open_pokemon_stats(pokemon, "OVERWORLD")
        return
    if move == "DROP":
        _deploy_selected_pokemon()
        return
    if move in ["SWITCH", "CANCEL"]:
        return
    if move == "TAKE ITEM":
        var held_item := String(entry.get("held_item", ""))
        if not held_item.is_empty():
            inventory[held_item] = int(inventory.get(held_item, 0)) + 1
            entry["held_item"] = ""
            caught_pokemon[pokemon_menu_index] = entry
            _show_message("Took %s from %s." % [held_item, PokemonData.battle_display_name(species)])
            pokemon_move_index = 0
            _refresh_pokemon_category_menu()
        return
    if move.begins_with("HOLD:"):
        var item_name := move.trim_prefix("HOLD:")
        if int(inventory.get(item_name, 0)) <= 0:
            _show_message("There is no %s left." % item_name)
            return
        var old_item := String(entry.get("held_item", ""))
        if not old_item.is_empty():
            inventory[old_item] = int(inventory.get(old_item, 0)) + 1
        inventory[item_name] = int(inventory.get(item_name, 0)) - 1
        entry["held_item"] = item_name
        caught_pokemon[pokemon_menu_index] = entry
        _show_message("%s is now holding %s." % [PokemonData.battle_display_name(species), item_name])
        pokemon_move_index = 0
        _refresh_pokemon_category_menu()
        return
    if _sleeping_bag_active():
        _show_message("Get up before using a Field Move.")
        return
    var activated := bool(world.set_active_field_move(entry, move))
    if not activated:
        # Gyarados and other fish follow only while their trainer is in water.
        if move == "FOLLOW" and bool(PokemonData.info(species).get("overworld_behavior", {}).get("swim_only", false)):
            _show_message("%s can only follow while swimming." % PokemonData.battle_display_name(species))
        else:
            _show_message("%s cannot follow here." % PokemonData.battle_display_name(species))
        return
    if move == "FLY":
        _play_pokemon_cry(entry)
    pokemon_menu_open = false
    pokemon_menu.visible = false
    game_menu_open = false
    game_menu.visible = false
    world.set_gameplay_enabled(true)
    touch_controls.set_game_active(true)
    if move == "BUILD":
        _open_build_menu()
    elif move == "FOLLOW":
        _show_message("%s is following you." % PokemonData.battle_display_name(species))
    else:
        if move not in ["CUT", "DIG"]:
            _show_message("%s is using %s." % [PokemonData.battle_display_name(species), move])

func _deploy_selected_pokemon() -> void:
    if caught_pokemon.is_empty():
        _show_message("There is no Pokemon to leave here.")
        return
    pokemon_menu_index = clampi(pokemon_menu_index, 0, caught_pokemon.size() - 1)
    var entry = caught_pokemon[pokemon_menu_index]
    if typeof(entry) != TYPE_DICTIONARY:
        return
    var keep_surf: bool = world.active_field_move == "SURF" and world.terrain_kind_at(world._player_cell()) == 0
    if keep_surf and _ensure_party_ecology_id(pokemon_menu_index) == String(world.active_field_pokemon.get("party_ecology_id","")):
        _show_message("Reach dry land before leaving your surfing POKEMON.")
        return
    if coop_game.active:
        coop_game.population.deploy(pokemon_menu_index,keep_surf)
        return
    if world.deploy_pokemon(entry):
        if not keep_surf: world.clear_active_field_move(false)
        var species := PokemonData.battle_display_name(String(entry.get("species", "POKEMON")))
        caught_pokemon.remove_at(pokemon_menu_index)
        pokemon_menu_open = false
        pokemon_menu.visible = false
        game_menu_open = false
        game_menu.visible = false
        world.set_gameplay_enabled(true)
        touch_controls.set_game_active(true)
        _show_message("The EGG was placed here." if bool(entry.get("is_egg", false)) else "%s was left in the habitat." % species)

func _show_item_menu() -> void:
    if item_pocket_menu.get_parent() != game_menu:
        item_pocket_menu.reparent(game_menu, false)
    item_pocket_menu.z_index = 100
    item_pocket_context = "OVERWORLD"
    battle_item_pocket_open = true
    battle_item_pocket_index = ItemData.POCKET_ITEMS
    battle_item_menu_index = 0
    item_menu_active = false
    game_menu_box.visible = false
    game_menu_detail.visible = false
    item_pocket_menu.visible = true
    _refresh_battle_item_pocket_menu()

func _handle_overworld_item_pocket_input(event: InputEvent) -> void:
    if planting_bag_target != null and field_item_busy:
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("cancel") or event.is_action_pressed("start"):
        _close_overworld_item_pocket_menu()
    elif (event.is_action_pressed("move_left") or
            event.is_action_pressed("shoulder_left")):
        _switch_battle_item_pocket(-1)
    elif (event.is_action_pressed("move_right") or
            event.is_action_pressed("shoulder_right")):
        _switch_battle_item_pocket(1)
    elif event.is_action_pressed("move_up"):
        battle_item_menu_index = wrapi(battle_item_menu_index - 1, 0,
            battle_item_menu_names.size() + 1)
        _refresh_battle_item_pocket_menu()
    elif event.is_action_pressed("move_down"):
        battle_item_menu_index = wrapi(battle_item_menu_index + 1, 0,
            battle_item_menu_names.size() + 1)
        _refresh_battle_item_pocket_menu()
    elif event.is_action_pressed("confirm"):
        _confirm_overworld_item_pocket()
    else:
        return
    get_viewport().set_input_as_handled()

func _close_overworld_item_pocket_menu() -> void:
    if planting_bag_target != null:
        planting_bag_target = null
        _close_game_menu()
        return
    battle_item_pocket_open = false
    item_pocket_context = ""
    item_pocket_menu.visible = false
    game_menu_box.visible = true

func _confirm_overworld_item_pocket() -> void:
    if battle_item_menu_index >= battle_item_menu_names.size():
        _close_overworld_item_pocket_menu()
        return
    var selected_item := ItemData.normalize_name(battle_item_menu_names[battle_item_menu_index])
    if planting_bag_target != null:
        if not world.is_empty_planting_hole(planting_bag_target) or not _planting_bag_item_allowed(selected_item):
            item_pocket_description.text = "That plant cannot grow here."
            return
        if int(inventory.get(selected_item, 0)) <= 0:
            _refresh_battle_item_pocket_menu()
            return
        field_item_busy = true
        game_menu.hide()
        var planted: bool = await world.plants().plant(planting_bag_target, selected_item)
        field_item_busy = false
        if planted:
            if not coop_game.active:_consume_inventory_item(selected_item)
            planting_bag_target = null
            world.planting_item = selected_item if int(inventory.get(selected_item,0)) > 0 else ""
            _close_game_menu()
        else:
            game_menu.show()
            world.set_gameplay_enabled(false)
        return
    bag_action_ui = preload("res://scripts/bag_item_actions.gd").new()
    $UI.add_child(bag_action_ui)
    bag_action_ui.open(self, selected_item)

func _use_overworld_item(item: String) -> void:
    if int(inventory.get(item, 0)) <= 0:
        _refresh_battle_item_pocket_menu()
        return
    if ItemData.is_evolution_item(item):
        overworld_evolution_item = item
        battle_item_pocket_open = false
        item_pocket_menu.hide()
        _show_pokemon_menu()
        _refresh_evolution_item_target()
        return
    if (preload("res://scripts/source_plant_farming.gd").plantable(item) or item == "SLEEPING BAG") and world.active_field_move == "SURF" and world.terrain_kind_at(world._player_cell()) == 0:
        _show_message("Reach dry land first.")
        return
    if preload("res://scripts/source_plant_farming.gd").plantable(item):
        world.clear_active_field_move(false)
        world.planting_item = item
        _leave_game_menu_for_field_action(true)
        _show_message("Face the soil and press A to plant." if item != "MANURE" else "Face a sapling or small tree and press A to fertilize.")
        return
    if item == "SLEEPING BAG":
        if not String(world.get("active_field_move")).is_empty():
            world.call("clear_active_field_move", false)
        if not bool(world.call("begin_sleeping_bag", _player_sleeping_texture())):
            return
        for party_index in range(caught_pokemon.size()):
            if typeof(caught_pokemon[party_index]) != TYPE_DICTIONARY or bool(
                    (caught_pokemon[party_index] as Dictionary).get("is_egg", false)):
                continue
            var resting_pokemon: Dictionary = BattleEngine.ensure_pokemon(caught_pokemon[party_index])
            BattleEngine.refill_pp(resting_pokemon)
            caught_pokemon[party_index] = resting_pokemon
        field_item_busy = true
        sleeping_bag_heal_accumulator = 0.0
        _leave_game_menu_for_field_action(false)
        return
    if item == "ESCAPE ROPE":
        if bool(world.call("use_escape_rope")):
            _leave_game_menu_for_field_action(true)
        return
    if item == "RARE CANDY":
        if caught_pokemon.is_empty():
            item_pocket_description.text = "There is no POKEMON to use it on."
            return
        var pokemon = BattleEngine.ensure_pokemon(caught_pokemon[0])
        if int(pokemon.get("level", 1)) >= 100:
            item_pocket_description.text = "It won't have any effect."
            return
        pokemon["level"] = int(pokemon.get("level", 1)) + 1
        PokemonState.apply_stats(pokemon, true)
        BattleEngine.refill_pp(pokemon)
        caught_pokemon[0] = pokemon
        _consume_inventory_item(item)
        _play_level_up_sound()
        _show_message("%s grew to level %d." % [
            PokemonState.display_name(pokemon), int(pokemon.get("level", 1))])
        _refresh_battle_item_pocket_menu()
        return
    if item in ["REPEL", "MAX REPEL"]:
        world.repel_until_elapsed = world.world_elapsed_seconds + (
            240.0 if item == "MAX REPEL" else 120.0)
        _consume_inventory_item(item)
        _leave_game_menu_for_field_action(true)
        _show_message("Used %s." % item)
        return
    if item in ["OLD ROD", "GOOD ROD", "SUPER ROD"]:
        _leave_game_menu_for_field_action(true)
        world.request_fishing_encounter(item)
        return
    if PokemonEcology.is_food(item):
        if not world.feed_pokemon_in_front(item):
            item_pocket_description.text = "Face a POKEMON to feed it."
            return
        _consume_inventory_item(item)
        _refresh_battle_item_pocket_menu()
        return
    item_pocket_description.text = "It won't have any effect here."

func _refresh_evolution_item_target() -> void:
    _refresh_pokemon_category_menu()
    if caught_pokemon.is_empty():
        return
    var target := BattleEngine.item_evolution_target(caught_pokemon[pokemon_menu_index], overworld_evolution_item)
    pokemon_menu_prompt.text = "%s: %s" % [overworld_evolution_item, "ABLE. A: USE" if not target.is_empty() else "NOT ABLE"]

func _handle_evolution_item_input(event: InputEvent) -> void:
    if event.is_action_pressed("cancel") or event.is_action_pressed("start"):
        overworld_evolution_item = ""
        pokemon_menu_open = false
        pokemon_menu.hide()
        var pocket := battle_item_pocket_index
        var selection := battle_item_menu_index
        _show_item_menu()
        battle_item_pocket_index = pocket
        battle_item_menu_index = selection
        _refresh_battle_item_pocket_menu()
    elif event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
        if not caught_pokemon.is_empty():
            pokemon_menu_index = wrapi(pokemon_menu_index + (-1 if event.is_action_pressed("move_up") else 1), 0, mini(6, caught_pokemon.size()))
            _refresh_evolution_item_target()
    elif event.is_action_pressed("confirm"):
        _use_evolution_item_on(pokemon_menu_index)
    else:
        return
    get_viewport().set_input_as_handled()

func _use_evolution_item_on(index: int) -> void:
    if overworld_evolution_running or index < 0 or index >= caught_pokemon.size():
        return
    var item := overworld_evolution_item
    if item.is_empty() or int(inventory.get(item, 0)) <= 0:
        return
    var pokemon: Dictionary = caught_pokemon[index]
    var target := BattleEngine.item_evolution_target(pokemon, item)
    if target.is_empty():
        pokemon_menu_prompt.text = "It won't have any effect."
        return
    var identity := _ensure_party_ecology_id(index)
    var field_move := String(world.active_field_move) if String(world.active_field_pokemon.get("party_ecology_id", "")) == identity else ""
    var following := String(world.follower_pokemon.get("party_ecology_id", "")) == identity
    overworld_evolution_item = ""
    overworld_evolution_running = true
    progression_active = true
    field_item_busy = true
    pokemon_menu_open = false
    pokemon_menu.hide()
    _leave_game_menu_for_field_action(false)
    world.set_gameplay_enabled(false)
    _consume_inventory_item(item)
    var previous_actor := battle_player
    battle_player = pokemon
    _reset_progression_overlay()
    var evolved := await _run_evolution_sequence(pokemon, target, index)
    if not evolved:
        inventory[item] = int(inventory.get(item, 0)) + 1
    elif not field_move.is_empty():
        world.set_active_field_move(pokemon, field_move)
    if evolved and following:
        world.set_follower(pokemon, false)
    battle_player = previous_actor
    _hide_progression_overlay()
    overworld_evolution_running = false
    progression_active = false
    field_item_busy = false
    world.set_gameplay_enabled(not _field_ui_blocks_gameplay())

func _consume_inventory_item(item: String) -> void:
    inventory[item] = maxi(0, int(inventory.get(item, 0)) - 1)

func _leave_game_menu_for_field_action(enable_world: bool) -> void:
    battle_item_pocket_open = false
    item_pocket_context = ""
    item_pocket_menu.visible = false
    game_menu_detail_open = false
    game_menu_open = false
    game_menu.visible = false
    if enable_world:
        world.set_gameplay_enabled(true)
        touch_controls.set_game_active(true)

func _sleeping_bag_active() -> bool:
    var sprite = world.get("sleeping_bag_sprite")
    return sprite is Sprite2D and is_instance_valid(sprite)

func _update_sleeping_bag_rest(delta: float) -> void:
    if battle_active:
        return
    if not field_item_busy or not _sleeping_bag_active():
        sleeping_bag_heal_accumulator = 0.0
        return
    sleeping_bag_heal_accumulator += delta
    var interval := 128.0 / 60.0 if world.bed_rest_active else 1.0
    while sleeping_bag_heal_accumulator >= interval:
        sleeping_bag_heal_accumulator -= interval
        var party_changed := false
        for party_index in range(caught_pokemon.size()):
            if typeof(caught_pokemon[party_index]) != TYPE_DICTIONARY or bool(
                    (caught_pokemon[party_index] as Dictionary).get(
                        "is_egg", false)):
                continue
            var pokemon := BattleEngine.ensure_pokemon(
                caught_pokemon[party_index])
            var old_hp := int(pokemon.get("hp", 0))
            var max_hp := maxi(1, int(pokemon.get("max_hp", 1)))
            if old_hp < max_hp:
                var recovery := (ceili(float(max_hp) / 25.0) + ceili(float(max_hp) / 15.0)) if world.bed_rest_active else (4 if world.active_area_id == "HOUSE" else 2)
                pokemon["hp"] = mini(max_hp, old_hp + recovery)
                party_changed = true
            # Source bed recovery clears status at full HP. Apply that same
            # completion rule to sleeping-bag rest, including full-HP status.
            if int(pokemon["hp"]) >= max_hp and not String(pokemon.get("status", "")).is_empty():
                pokemon["status"] = ""
                pokemon["status_counter"] = 0
                pokemon["toxic_counter"] = 0
                party_changed = true
            caught_pokemon[party_index] = pokemon
        if party_changed and pokemon_menu_open and pokemon_menu != null and \
                pokemon_menu.visible:
            _refresh_party_list_rows(
                pokemon_party_rows, caught_pokemon, pokemon_menu_index)

func _end_sleeping_bag_rest() -> void:
    if not _sleeping_bag_active():
        return
    var was_bed: bool = world.bed_rest_active
    world.call("end_sleeping_bag")
    field_item_busy = false
    sleeping_bag_heal_accumulator = 0.0
    world.set_gameplay_enabled(true)
    touch_controls.set_game_active(true)
    _show_message("You got out of bed." if was_bed else "Your POKEMON rested. This is now your return point.")

func _show_map_menu() -> void:
    game_menu_open = true
    game_menu.show()
    world.set_gameplay_enabled(false)
    $UI/GameMenu/MapScreen/Hint.text = "DPAD/STICK: CURSOR  R STICK: PAN\nL/R: ZOOM  " + ("Waypoint: A  " if GameOptions.enabled("map_waypoint") else "") + "B: BACK"
    $UI/GameMenu/MapScreen/Hint.add_theme_constant_override("line_spacing", 0)
    if not is_instance_valid(waypoint_ui):
        waypoint_ui=preload("res://scripts/map_waypoints.gd").new()
        add_child(waypoint_ui)
        waypoint_ui.configure(self)
    teleport_map_mode = false
    teleport_destinations.clear()
    game_menu_detail_open = true
    game_menu_box.visible = false
    game_menu_detail.visible = false
    game_menu_map_screen.visible = true
    game_menu_map.visible = true
    map_zoom = DEFAULT_MAP_ZOOM
    map_pan = Vector2.ZERO
    var requested_map_serial := map_build_serial + 1
    await _draw_world_map()
    if map_build_serial == requested_map_serial and is_instance_valid(map_view_node) and game_menu_map_screen.visible:
        waypoint_ui.setup_map()

func _open_teleport_map(destinations: Array) -> void:
    if destinations.is_empty():
        _show_message("There are no BEACONS to TELEPORT to.")
        return
    teleport_map_mode = true
    teleport_destinations = destinations.duplicate(true)
    teleport_destination_index = 0
    game_menu_open = true
    game_menu_detail_open = true
    game_menu.visible = true
    game_menu_box.visible = false
    game_menu_detail.visible = false
    game_menu_map_screen.visible = true
    game_menu_map.visible = true
    world.set_gameplay_enabled(false)
    touch_controls.set_game_active(true)
    map_zoom = DEFAULT_MAP_ZOOM
    map_pan = Vector2.ZERO
    var requested_map_serial := map_build_serial + 1
    await _draw_world_map()
    if map_build_serial == requested_map_serial and game_menu_map_screen.visible: _refresh_teleport_map_selection()

func _cycle_teleport_destination(direction: int) -> void:
    if teleport_destinations.is_empty():
        return
    teleport_destination_index = wrapi(teleport_destination_index + direction, 0, teleport_destinations.size())
    _refresh_teleport_map_selection()

func _refresh_teleport_map_selection() -> void:
    if teleport_destinations.is_empty() or map_view_node == null:
        return
    var destination: Dictionary = teleport_destinations[teleport_destination_index]
    var cell: Vector2i = destination.get("cell", Vector2i.ZERO)
    var bounds: Rect2i = world.call("get_map_bounds") if world.has_method("get_map_bounds") else Rect2i(Vector2i.ZERO, Vector2i(int(world.get("map_w")), int(world.get("map_h"))))
    var local_center := Vector2(
        float(cell.x - bounds.position.x) / maxf(1.0, float(bounds.size.x)) * map_view_node.size.x,
        float(cell.y - bounds.position.y) / maxf(1.0, float(bounds.size.y)) * map_view_node.size.y
    )
    map_pan = (map_view_node.size * 0.5 - local_center) * map_zoom
    _update_map_transform()
    if teleport_name_label == null or not is_instance_valid(teleport_name_label):
        teleport_name_label = Label.new()
        teleport_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        teleport_name_label.add_theme_font_override("font", JOHTO_FONT)
        teleport_name_label.add_theme_font_size_override("font_size", 8)
        teleport_name_label.position = Vector2(8, 134)
        teleport_name_label.size = Vector2(304, 18)
        teleport_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        teleport_name_label.z_index = 100
        game_menu_map.add_child(teleport_name_label)
    teleport_name_label.text = "%s   %d/%d" % [
        String(destination.get("name", "BEACON")),
        teleport_destination_index + 1, teleport_destinations.size()]

func _draw_world_map() -> void:
    _clear_map_canvas()
    var bounds := Rect2i(
        Vector2i.ZERO,
        Vector2i(int(world.get("map_w")), int(world.get("map_h")))
    )
    if world.has_method("get_map_bounds"):
        bounds = world.call("get_map_bounds")
    if bounds.size.x <= 0 or bounds.size.y <= 0:
        return
    map_building = true
    var serial := map_build_serial
    var loading := _source_ui_label(game_menu_map,"MapLoading",Vector2(8,60),Vector2(304,20),9,"DRAWING MAP...")
    loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var raster: Texture2D = map_art_cache if map_art_cache_context == preload("res://scripts/source_map_raster.gd").context_key(self, bounds) else null
    if raster == null:
        raster = await preload("res://scripts/source_map_raster.gd").build(self, bounds, serial)
    if serial != map_build_serial or raster == null: return
    loading.queue_free()
    map_building = false
    var image_size := bounds.size * SOURCE_MAP_TILE_PIXELS
    var map_texture: Texture2D = raster
    var map_view := TextureRect.new()
    map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    map_view.texture = map_texture
    map_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    map_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    map_view.stretch_mode = TextureRect.STRETCH_SCALE
    map_view.size = Vector2(image_size)
    map_view_node = map_view
    game_menu_map.add_child(map_view)

    var marker := TextureRect.new()
    marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var player = world.get_node("Player")
    var appearance_texture := _player_appearance_texture(false)
    if appearance_texture != null:
        var marker_frame := AtlasTexture.new()
        marker_frame.atlas = appearance_texture
        # The Java minimap draws the full 16x11 head/upper-body region. The
        # old 8-pixel crop removed most hats and made the marker easy to hide.
        marker_frame.region = Rect2(0.0, 0.0, 16.0, 11.0)
        marker.texture = marker_frame
    marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    marker.z_index = 20
    var player_cell: Vector2i = Vector2i(
        int(floor(player.position.x / 16.0)),
        int(floor(player.position.y / 16.0))
    )
    var marker_size := MAP_MARKER_DISPLAY_SIZE
    var marker_center := Vector2(
        float(player_cell.x - bounds.position.x) * SOURCE_MAP_TILE_PIXELS,
        float(player_cell.y - bounds.position.y) * SOURCE_MAP_TILE_PIXELS
    )
    marker.position = Vector2(
        clampf(
            marker_center.x - marker_size.x * 0.5,
            0.0,
            maxf(0.0, float(image_size.x) - marker_size.x)
        ),
        clampf(
            marker_center.y - marker_size.y * 0.5,
            0.0,
            maxf(0.0, float(image_size.y) - marker_size.y)
        )
    )
    marker.size = marker_size
    marker.pivot_offset = marker_size * 0.5
    map_marker_node = marker
    map_view.add_child(marker)
    _add_map_other_players(map_view, bounds, image_size, marker_size)

    # Separate respawn marker using the authored sleeping-bag sprite. Only show
    # it after the player has actually set a respawn point.
    var respawn: Vector2i = world.get("respawn_cell")
    if respawn.x > -2147483648 and bounds.has_point(respawn):
        var bag_marker := TextureRect.new()
        bag_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bag_marker.texture = MAP_SLEEPING_BAG_TEXTURE
        bag_marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        bag_marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        bag_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        bag_marker.z_index = 19
        var bag_center := Vector2(
            float(respawn.x - bounds.position.x) * SOURCE_MAP_TILE_PIXELS,
            float(respawn.y - bounds.position.y) * SOURCE_MAP_TILE_PIXELS
        )
        bag_marker.size = MAP_SLEEPING_BAG_DISPLAY_SIZE
        bag_marker.position = bag_center - bag_marker.size * 0.5
        bag_marker.pivot_offset = bag_marker.size * 0.5
        map_sleeping_bag_node = bag_marker
        map_view.add_child(bag_marker)

    # Open on the player's discovered area instead of the center of the full
    # generated landmass, where the explored patch looked tiny.
    var marker_local_center := marker.position + marker.size * 0.5
    map_pan = (map_view.size * 0.5 - marker_local_center) * map_zoom
    _update_map_transform()

func _paint_source_map_tile(image: Image, destination: Vector2i,
        spec: Dictionary, texture_images: Dictionary,
        map_tile_previews: Dictionary) -> void:
    if spec.is_empty():
        return
    var texture := spec.get("texture") as Texture2D
    if texture == null:
        return
    var texture_id := texture.get_instance_id()
    if not texture_images.has(texture_id):
        texture_images[texture_id] = texture.get_image()
    var source: Image = texture_images[texture_id]
    if source == null:
        return
    var region: Rect2 = spec.get("region", Rect2(0, 0, 16, 16))
    var offset: Vector2 = spec.get("offset", Vector2.ZERO)
    var preview_key := "%d|%s" % [texture_id, region]
    if not map_tile_previews.has(preview_key):
        var preview := source.get_region(Rect2i(region))
        preview.resize(
            maxi(1, roundi(region.size.x * SOURCE_MAP_TILE_PIXELS / 16.0)),
            maxi(1, roundi(region.size.y * SOURCE_MAP_TILE_PIXELS / 16.0)),
            Image.INTERPOLATE_NEAREST)
        map_tile_previews[preview_key] = preview
    var tile_image: Image = map_tile_previews[preview_key]
    var map_offset := Vector2i((offset * SOURCE_MAP_TILE_PIXELS / 16.0).round())
    image.blend_rect(tile_image,
        Rect2i(Vector2i.ZERO, tile_image.get_size()),
        destination + map_offset)

func _update_map_transform() -> void:
    if map_view_node == null or not is_instance_valid(map_view_node):
        return
    _clamp_map_pan()
    map_view_node.scale = Vector2(map_zoom, map_zoom)
    map_view_node.position = MAP_VIEWPORT_CENTER + map_pan - \
        map_view_node.size * map_zoom * 0.5
    if is_instance_valid(waypoint_ui):waypoint_ui.update_markers()
    var inverse_zoom := 1.0 / maxf(map_zoom, 0.01)
    if map_marker_node != null and is_instance_valid(map_marker_node):
        # Terrain zoom must not turn the locator into a giant head.
        map_marker_node.scale = Vector2(inverse_zoom, inverse_zoom)
    for other in map_other_markers:
        if is_instance_valid(other):
            other.scale = Vector2(inverse_zoom, inverse_zoom)
    if map_sleeping_bag_node != null and is_instance_valid(map_sleeping_bag_node):
        map_sleeping_bag_node.scale = Vector2(inverse_zoom, inverse_zoom)

func _set_map_zoom(value: float) -> void:
    var old_zoom := maxf(map_zoom, 0.01)
    map_zoom = clampf(value, 0.75 / SOURCE_MAP_TILE_PIXELS, 1.0)
    # Preserve the local point currently under the screen center.
    map_pan *= map_zoom / old_zoom
    _update_map_transform()

func _clamp_map_pan() -> void:
    if map_view_node == null or not is_instance_valid(map_view_node):
        return
    var scaled_size := map_view_node.size * map_zoom
    var limit := Vector2(
        maxf(0.0, (scaled_size.x - MAP_VIEWPORT_SIZE.x) * 0.5),
        maxf(0.0, (scaled_size.y - MAP_VIEWPORT_SIZE.y) * 0.5)
    )
    map_pan.x = clampf(map_pan.x, -limit.x, limit.x)
    map_pan.y = clampf(map_pan.y, -limit.y, limit.y)

func _clear_map_canvas() -> void:
    map_build_serial += 1
    map_building = false
    teleport_name_label = null
    for child in game_menu_map.get_children():
        child.queue_free()
    map_view_node = null
    map_marker_node = null
    map_sleeping_bag_node = null

func _show_guide_menu() -> void:
    guide_menu_open = true
    guide_topic_open = false
    guide_menu_index = 0
    game_menu_box.visible = false
    game_menu_detail.visible = false
    guide_menu.visible = true
    _refresh_guide_menu()

func _refresh_guide_menu() -> void:
    var window_start := maxi(0, guide_menu_index - 3)
    window_start = mini(
        window_start, maxi(0, GUIDE_TOPICS.size() - guide_menu_rows.size())
    )
    for row in range(guide_menu_rows.size()):
        var topic_index := window_start + row
        guide_menu_rows[row].text = (
            String((GUIDE_TOPICS[topic_index] as Dictionary).get("name", ""))
            if topic_index < GUIDE_TOPICS.size()
            else ""
        )
    var visible_row := guide_menu_index - window_start
    _align_menu_tick(guide_menu_cursor, guide_menu_rows[visible_row])
    guide_menu_up_arrow.visible = window_start > 0
    guide_menu_down_arrow.visible = (
        window_start + guide_menu_rows.size() < GUIDE_TOPICS.size()
    )

func _show_selected_guide_topic() -> void:
    var topic: Dictionary = GUIDE_TOPICS[guide_menu_index]
    guide_menu.visible = false
    guide_topic_open = true
    game_menu_detail_open = true
    game_menu_detail.visible = true
    game_menu_detail_title.text = String(topic.get("name", "GUIDE"))
    game_menu_detail_body.text = String(topic.get("body", ""))
    game_menu_map.visible = false
    game_menu_map_screen.visible = false

func _open_save_confirmation() -> void:
    save_confirm_open = true
    save_confirm_index = 0
    game_menu_box.visible = false
    game_menu_detail.visible = false
    save_confirm.visible = true
    _update_save_confirm_cursor()

func _close_save_confirmation() -> void:
    save_confirm_open = false
    save_confirm.visible = false
    game_menu_box.visible = true

func _update_save_confirm_cursor() -> void:
    # Reference layout: YES on the left, NO on the right.
    if save_confirm_index == 0:
        save_confirm_cursor.position = Vector2(22.0, 57.0)
    else:
        save_confirm_cursor.position = Vector2(134.0, 57.0)
    _align_menu_tick(save_confirm_cursor, save_confirm.get_node("Yes" if save_confirm_index == 0 else "No"))

func _safe_world_filename(world_name: String) -> String:
    var clean = world_name.strip_edges().to_lower()
    if clean.is_empty():
        clean = "pokewilds"
    var result = ""
    for ch in clean:
        if ch.is_valid_identifier() or ch.is_valid_int():
            result += ch
        elif ch == " " or ch == "-" or ch == "_":
            result += "_"
    if result.is_empty():
        result = "pokewilds"
    return result

func _save_path_for_world(world_name: String) -> String:
    return "%s/%s.json" % [SAVE_DIR, _safe_world_filename(world_name)]

func _ensure_save_directory() -> bool:
    var absolute_dir = ProjectSettings.globalize_path(SAVE_DIR)
    var err = DirAccess.make_dir_recursive_absolute(absolute_dir)
    return err == OK or err == ERR_ALREADY_EXISTS

func _indexed_save_path(stored: String) -> String:
    # Old indexes contain private/device-specific absolute paths. The selected
    # save directory is authoritative after migration or a drag-and-drop copy.
    return "" if stored.is_empty() else SAVE_DIR.path_join(stored.get_file())

func _write_save_index(world_name: String, save_path: String) -> void:
    var cfg = ConfigFile.new()
    cfg.load(SAVE_INDEX_PATH)
    var key = _safe_world_filename(world_name)
    cfg.set_value("worlds", key, save_path.get_file())
    cfg.set_value("last", "world_name", world_name)
    cfg.set_value("last", "save_path", save_path.get_file())
    cfg.save(SAVE_INDEX_PATH)

func _read_save_file(save_path: String) -> Dictionary:
    if save_path.is_empty() or not FileAccess.file_exists(save_path):
        return {}
    var file := FileAccess.open(save_path, FileAccess.READ)
    if file == null:
        return {}
    var text := file.get_as_text()
    file.close()
    var parsed = JSON.parse_string(text)
    if typeof(parsed) == TYPE_DICTIONARY:
        return parsed
    return {}

func _find_newest_valid_save() -> String:
    if not _ensure_save_directory():
        return ""

    var cfg := ConfigFile.new()
    if cfg.load(SAVE_INDEX_PATH) == OK:
        var indexed := _indexed_save_path(String(cfg.get_value("last", "save_path", "")))
        if not _read_save_file(indexed).is_empty():
            return indexed

    var dir := DirAccess.open(SAVE_DIR)
    if dir == null:
        return ""

    var newest := ""
    var newest_time := 0
    dir.list_dir_begin()
    var file_name := dir.get_next()
    while not file_name.is_empty():
        if not dir.current_is_dir() and file_name.to_lower().ends_with(".json"):
            var candidate := "%s/%s" % [SAVE_DIR, file_name]
            if not _read_save_file(candidate).is_empty():
                var modified := int(FileAccess.get_modified_time(candidate))
                if newest.is_empty() or modified >= newest_time:
                    newest = candidate
                    newest_time = modified
        file_name = dir.get_next()
    dir.list_dir_end()
    return newest

func _find_save_path(world_name: String) -> String:
    if not _ensure_save_directory():
        return ""

    var direct_file := _save_path_for_world(world_name)
    if not _read_save_file(direct_file).is_empty():
        return direct_file

    var cfg := ConfigFile.new()
    if cfg.load(SAVE_INDEX_PATH) == OK:
        var key := _safe_world_filename(world_name)
        var indexed := _indexed_save_path(String(cfg.get_value("worlds", key, "")))
        if not _read_save_file(indexed).is_empty():
            return indexed

        var last_name := String(cfg.get_value("last", "world_name", ""))
        var last_path := _indexed_save_path(String(cfg.get_value("last", "save_path", "")))
        if (world_name.strip_edges().is_empty() or last_name == world_name) and not _read_save_file(last_path).is_empty():
            return last_path

    return _find_newest_valid_save()

func _capture_game_save(version: int = 2, personal_only: bool = false) -> Dictionary:
    var player = world.get_node("Player")
    var world_name = world_edit.text.strip_edges()
    if world_name.is_empty():
        world_name = "PokeWilds"

    return {
        "version": version,
        "world_seed": int(world.get("world_seed")),
        "world_size": int(world.get("map_size_index")),
        "world_name": world_name,
        "player_name": player_model_name.text,
        "player_name_custom": not custom_player_name.is_empty(),
        "player_color": player_color_index,
        "player_model": player_model_index,
        "player_x": player.position.x,
        "player_y": player.position.y,
        "options": GameOptions.values.duplicate(),
        "waypoints": map_waypoints.duplicate(true),
        "pokedex": pokedex_progress.entries.duplicate(),
        "pokedex_shiny": pokedex_progress.shiny_entries.duplicate(),
        "caught_pokemon": caught_pokemon,
        "pokemon_storage": pokemon_storage,
        "preferred_storage_box": preferred_storage_box,
        "inventory": inventory,
        "source_key_items_initialized": true,
        "egg_step_timer": egg_step_timer,
        "friendship_step_timer": friendship_step_timer,
        "next_party_ecology_id": next_party_ecology_id,
        "adjacent_worlds": adjacent_worlds,
        "world_grid_x": current_world_grid.x,
        "world_grid_y": current_world_grid.y,
        "crafting_state": preload("res://scripts/coop_world_snapshot.gd").capture_personal(world) if personal_only else world.get_crafting_save_state()
    }


func _save_current_game() -> void:
    _sync_pokedex_owned()
    if not _ensure_save_directory():
        _close_save_confirmation()
        _show_message("SAVE FAILED.")
        return

    var data = _capture_game_save()
    var world_name = String(data.world_name)
    if coop_game.active:
        var saved_ok: bool = await coop_game.save_game(data)
        _close_save_confirmation()
        if saved_ok:
            _close_game_menu();world.call("play_source_sound","save1");_show_message("GAME SAVED.")
        else: _show_message("SAVE FAILED.")
        return

    var save_path = _save_path_for_world(world_name)
    var file = FileAccess.open(save_path, FileAccess.WRITE)
    if file == null:
        _close_save_confirmation()
        _show_message("SAVE FAILED.")
        return

    data["storage_shared"] = true
    data["storage_serial"] = shared_storage_serial + 1
    file.store_string(JSON.stringify(data))
    file.flush()
    file.close()

    if not FileAccess.file_exists(save_path):
        _close_save_confirmation()
        _show_message("SAVE FAILED.")
        return

    _write_shared_storage()
    _write_save_index(world_name, save_path)
    world_edit.text = world_name
    _save_setup()

    await shared_save_folder.export_files(self)
    _close_save_confirmation()
    _close_game_menu()
    world.call("play_source_sound", "save1")
    _show_message("GAME SAVED.")

## Writes the SHARED chest's contents after the save that goes with them, so
## that what is stored always matches a saved party. If this write is lost,
## that save's own copy is the newer one and is used when it is next loaded.
func _write_shared_storage() -> void:
    shared_storage_serial += 1
    var held = pokemon_storage.get(SHARED_STORAGE_KEY, [])
    var error: Error = preload("res://scripts/shared_storage.gd").write(
        {SHARED_STORAGE_KEY: held if held is Array else []}, shared_storage_serial)
    if error != OK:
        push_error("Shared storage could not be written (%d)." % error)

func _read_game_save(world_name: String):
    return _read_save_file(_find_save_path(world_name))

func _restore_game_save(data) -> void:
    GameOptions.restore_game_options(data.get("options", {}),String(data.get("world_name","")))
    _apply_game_options()
    map_waypoints = (data.get("waypoints", {}) as Dictionary).duplicate(true)
    if not is_instance_valid(waypoint_ui):
        waypoint_ui=preload("res://scripts/map_waypoints.gd").new();add_child(waypoint_ui);waypoint_ui.configure(self)
    pokedex_progress.restore(data.get("pokedex", {}))
    pokedex_progress.restore_shiny(data.get("pokedex_shiny", {}))
    adjacent_worlds = (data.get("adjacent_worlds", {}) as Dictionary).duplicate(true)
    current_world_grid = Vector2i(int(data.get("world_grid_x", 0)), int(data.get("world_grid_y", 0)))
    world_edit.text = String(data.get("world_name", world_edit.text))
    player_color_index = clampi(
        int(data.get("player_color", player_color_index)),
        0,
        PLAYER_TEXTURES.size() - 1
    )
    player_model_index = clampi(
        int(data.get("player_model", player_model_index)),
        0,
        _player_model_count() - 1
    )
    var saved_player_name := String(data.get("player_name", "")).strip_edges().left(24)
    var was_custom := bool(data.get("player_name_custom", not saved_player_name.is_empty() and saved_player_name.to_upper() != PLAYER_MODEL_NAMES[player_model_index].to_upper()))
    custom_player_name = saved_player_name if was_custom else ""
    _apply_player_appearance()
    _apply_world_player_textures()
    egg_step_timer = clampi(
        int(data.get("egg_step_timer", 0)),
        0,
        PokemonEcology.EGG_STEP_INTERVAL - 1
    )
    friendship_step_timer = clampi(
        int(data.get("friendship_step_timer", 0)),
        0,
        PokemonEcology.FRIENDSHIP_STEP_INTERVAL - 1
    )
    next_party_ecology_id = maxi(
        1, int(data.get("next_party_ecology_id", 1))
    )

    caught_pokemon.clear()
    caught_species.clear()
    var saved_party = data.get("caught_pokemon", [])
    if typeof(saved_party) == TYPE_ARRAY:
        for entry in saved_party:
            if typeof(entry) == TYPE_DICTIONARY:
                caught_pokemon.append(entry)
                var species = String(entry.get("species", ""))
                if not species.is_empty() and not caught_species.has(species):
                    caught_species.append(species)

    var saved_inventory = data.get("inventory", {})
    if typeof(saved_inventory) == TYPE_DICTIONARY:
        inventory = CraftingData.ensure_inventory(saved_inventory)
    else:
        inventory = CraftingData.ensure_inventory(STARTING_INVENTORY)
    if not bool(data.get("source_key_items_initialized", false)):
        inventory["SLEEPING BAG"] = maxi(1, int(inventory.get("SLEEPING BAG", 0)))
        inventory["ESCAPE ROPE"] = maxi(1, int(inventory.get("ESCAPE ROPE", 0)))

    preferred_storage_box = String(data.get("preferred_storage_box", ""))
    var saved_storage = data.get("pokemon_storage", {})
    pokemon_storage = saved_storage.duplicate(true) if typeof(saved_storage) == TYPE_DICTIONARY else {}

    var crafting_state = data.get("crafting_state", {})
    if typeof(crafting_state) == TYPE_DICTIONARY:
        await world.restore_crafting_save_state(crafting_state)

    var player = world.get_node("Player")
    player.position = Vector2(
        float(data.get("player_x", player.position.x)),
        float(data.get("player_y", player.position.y))
    )
    if typeof(crafting_state) == TYPE_DICTIONARY:
        player.position = world.migrate_source_interior_position(player.position, crafting_state)
    if world.has_method("reveal_player_area"):
        world.call("reveal_player_area")
    _recover_hidden_party_overflow()
    _sync_pokedex_owned()

func _open_crafting_menu(station: String) -> void:
    if craft_menu_open or game_menu_open or battle_active:
        return
    craft_station = station
    craft_index = 0
    craft_menu_open = true
    crafting_panel.visible = true
    world.set_gameplay_enabled(false)
    touch_controls.set_game_active(true)
    world.call("play_source_sound", "menu_open1")
    _refresh_crafting_menu()

func _close_crafting_menu() -> void:
    craft_menu_open = false
    crafting_panel.visible = false
    world.set_gameplay_enabled(true)
    touch_controls.set_game_active(true)

func _find_party_builder_index() -> int:
    for index in range(caught_pokemon.size()):
        var raw_pokemon = caught_pokemon[index]
        if typeof(raw_pokemon) != TYPE_DICTIONARY:
            continue
        var pokemon := raw_pokemon as Dictionary
        if bool(pokemon.get("is_egg", false)) or int(pokemon.get("hp", 1)) <= 0:
            continue
        if FieldMoveData.field_moves_for(String(pokemon.get("species", "")), String(pokemon.get("form", ""))).has("BUILD"):
            return index
    return -1

func _open_build_menu() -> void:
    if build_menu_open or craft_menu_open or game_menu_open or battle_active or not started:
        return
    var builder_index := _find_party_builder_index()
    if builder_index < 0:
        _show_message("A FIGHTING-type Pokemon is needed to BUILD.")
        return

    _ensure_party_ecology_id(builder_index)
    var builder := caught_pokemon[builder_index] as Dictionary
    var active_move := String(world.get("active_field_move"))
    var active_builder := String(world.get("active_field_species"))
    var helper_missing := (world.get("field_helper_pokemon") as Dictionary).is_empty()
    if active_move != "BUILD" or active_builder != String(builder.get("species", "")).to_lower() or helper_missing:
        if not bool(world.set_active_field_move(builder, "BUILD")):
            _show_message("There is no room for %s to BUILD here." % PokemonData.battle_display_name(String(builder.get("species", "POKEMON"))))
            return

    build_menu_index = int(world.call("get_build_selection_index"))
    build_menu_open = true
    build_panel.visible = true
    message_panel.visible = false
    world.call("set_build_preview_active", true)
    world.set_gameplay_enabled(true)
    touch_controls.set_game_active(true)
    _refresh_build_menu()

func _close_build_menu(stop_building: bool = true) -> void:
    build_menu_open = false
    build_panel.visible = false
    world.call("set_build_preview_active", false)
    if stop_building and String(world.get("active_field_move")) == "BUILD":
        world.call("clear_active_field_move", true)
    world.set_gameplay_enabled(not _field_ui_blocks_gameplay())
    touch_controls.set_game_active(true)

func _handle_build_menu_input(event: InputEvent) -> void:
    var recipe_count := CraftingData.build_recipes().size()
    if event.is_action_pressed("shoulder_left"):
        if recipe_count > 0:
            build_menu_index = wrapi(build_menu_index - 1, 0, recipe_count)
            _refresh_build_menu()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("shoulder_right"):
        if recipe_count > 0:
            build_menu_index = wrapi(build_menu_index + 1, 0, recipe_count)
            _refresh_build_menu()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("confirm"):
        if recipe_count > 0:
            world.call("set_build_selection_index", build_menu_index)
            var recipe := CraftingData.build_recipes()[build_menu_index] as Dictionary
            var build_name := String(recipe.get("name", ""))
            var target: Vector2i = world.call("get_build_execution_cell")
            _on_build_requested(build_name, target)
            _refresh_build_menu()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("cancel") or event.is_action_pressed("build_menu"):
        _close_build_menu()
        get_viewport().set_input_as_handled()

func _refresh_build_menu() -> void:
    var recipes := CraftingData.build_recipes()
    if recipes.is_empty():
        build_list.text = "NO BUILD RECIPES"
        build_cost.text = ""
        build_cursor.visible = false
        return
    build_menu_index = clampi(build_menu_index, 0, recipes.size() - 1)
    _apply_build_hud_selection()
    world.call("set_build_selection_index", build_menu_index)
    world.call("set_build_preview_active", true)

func _apply_build_hud_selection() -> void:
    var recipes := CraftingData.build_recipes()
    if recipes.is_empty():
        return
    build_menu_index = clampi(build_menu_index, 0, recipes.size() - 1)
    var selected := recipes[build_menu_index] as Dictionary
    var cost: Dictionary = selected.get("cost", {})
    build_title.text = String(selected.get("display_name", selected.get("name", ""))).to_upper()
    build_list.text = ""
    build_cursor.visible = false
    build_cost.text = _format_need_box(cost)
    # Four lines for the three-material recipe still fit the matched 48px box.
    var compact_cost := cost.size() > 2
    build_cost.position.y = 6.0 if compact_cost else 8.0
    build_cost.size.y = 36.0 if compact_cost else 34.0
    build_cost.add_theme_constant_override("line_separation", -3 if compact_cost else 0)

func _on_world_build_selection_changed(index: int) -> void:
    if not build_menu_open or CraftingData.build_recipes().is_empty():
        return
    var normalized := wrapi(index, 0, CraftingData.build_recipes().size())
    if normalized == build_menu_index:
        return
    build_menu_index = normalized
    # World input can receive shoulder events first while gameplay stays live
    # in BUILD mode.  Update the two visible boxes from that authoritative
    # selection without sending the value back and causing a signal loop.
    _apply_build_hud_selection()

func _handle_crafting_input(event: InputEvent) -> void:
    var recipes := CraftingData.recipes_for_station(craft_station)
    if event.is_action_pressed("move_up"):
        if not recipes.is_empty():
            craft_index = wrapi(craft_index - 1, 0, recipes.size())
            world.call("play_source_sound", "menu_switch2")
            _refresh_crafting_menu()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("move_down"):
        if not recipes.is_empty():
            craft_index = wrapi(craft_index + 1, 0, recipes.size())
            world.call("play_source_sound", "menu_switch2")
            _refresh_crafting_menu()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("move_left") or event.is_action_pressed("shoulder_left"):
        if not recipes.is_empty():
            craft_index = wrapi(craft_index - 1, 0, recipes.size())
            world.call("play_source_sound", "menu_switch2")
            _refresh_crafting_menu()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("move_right") or event.is_action_pressed("shoulder_right"):
        if not recipes.is_empty():
            craft_index = wrapi(craft_index + 1, 0, recipes.size())
            world.call("play_source_sound", "menu_switch2")
            _refresh_crafting_menu()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("confirm"):
        _craft_selected_recipe()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("cancel") or event.is_action_pressed("start"):
        _close_crafting_menu()
        get_viewport().set_input_as_handled()

func _refresh_crafting_menu() -> void:
    var recipes := CraftingData.recipes_for_station(craft_station)
    if recipes.is_empty():
        crafting_title.text = "No recipes"
        crafting_list.text = "NO RECIPES"
        crafting_cost.text = ""
        crafting_cursor.visible = false
        return

    craft_index = clampi(craft_index, 0, recipes.size() - 1)
    var selected: Dictionary = recipes[craft_index]
    crafting_title.text = String(selected.get("name", "")).capitalize()
    crafting_list.text = ""
    crafting_cursor.visible = false
    var crafting_cost_data: Dictionary = selected.get("cost", {})
    crafting_cost.text = _format_need_box(crafting_cost_data)

func _format_need_box(cost: Dictionary) -> String:
    var lines: Array[String] = ["NEED"]
    for raw_name in cost.keys():
        var item_name := String(raw_name).to_upper()
        var required := int(cost[raw_name])
        var enough := int(inventory.get(raw_name, 0)) >= required
        if enough:
            lines.append("%s x%d" % [item_name, required])
        else:
            lines.append("[font=res://assets/source_text_font_gray.fnt]%s x%d[/font]" % [
                item_name, required])
    return "\n".join(lines)

func _craft_selected_recipe() -> void:
    var recipes := CraftingData.recipes_for_station(craft_station)
    if recipes.is_empty():
        return
    var recipe: Dictionary = recipes[craft_index]
    var cost: Dictionary = recipe.get("cost", {})
    var output := String(recipe.get("name", ""))
    if not CraftingData.can_afford(inventory, cost):
        world.call("play_source_sound", "error1")
        _show_message("Not enough materials for %s." % output)
        return
    if (
            bool(recipe.get("event", false))
            and craft_station == "REGI FORGE"
            and world.has_method("can_awaken_regi")
            and not bool(world.call("can_awaken_regi", output))
        ):
        _show_message("That Regi has already answered the pedestal.")
        return
    CraftingData.consume(inventory, cost)
    world.call("play_source_sound", "click1")
    if bool(recipe.get("event", false)):
        if craft_station == "REGI FORGE":
            if world.complete_regi_forge(output):
                _close_crafting_menu()
            else:
                _show_message("The pedestal did not respond.")
        elif craft_station == "FOSSIL REVIVER":
            _close_crafting_menu()
            _revive_fossil(output)
        else:
            _show_message("%s awakened!" % output)
    else:
        CraftingData.grant(inventory, output, 1)
        _show_message("Crafted %s." % output)
    if craft_menu_open:
        _refresh_crafting_menu()

func _revive_fossil(fossil_name: String) -> void:
    var species := String(SourceEventData.FOSSIL_SPECIES.get(fossil_name, ""))
    if species.is_empty():
        _show_message("The machine could not read that fossil.")
        return
    var level_total := 0
    var level_count := 0
    for raw_pokemon in caught_pokemon:
        if typeof(raw_pokemon) != TYPE_DICTIONARY:
            continue
        var pokemon := raw_pokemon as Dictionary
        if bool(pokemon.get("is_egg", false)):
            continue
        level_total += maxi(1, int(pokemon.get("level", 1)))
        level_count += 1
    var average_level := 5 if level_count == 0 else int(floor(float(level_total) / float(level_count)))
    var revived_level := clampi(average_level - 3 + battle_rng.randi_range(0, 2), 1, 50)
    var revived := BattleEngine.make_pokemon(species, revived_level)
    if String(world.get("active_field_move")) == "CHARM":
        var destination := _route_received_pokemon(revived)
        if not caught_species.has(species):
            caught_species.append(species)
        var notice := _received_pokemon_notice(revived, destination)
        _show_message("%s was revived from the %s!" % [PokemonData.battle_display_name(species), fossil_name] if notice.is_empty() else notice)
        return
    _show_message("%s was revived... and attacked!" % PokemonData.battle_display_name(species))
    _start_battle_context({
        "id": "fossil_%s" % species,
        "kind": "fossil",
        "intro": "%s was revived... and attacked!" % PokemonData.battle_display_name(species),
        "can_run": true,
        "can_catch": true,
        "clear_on_capture": false,
        "clear_on_defeat": false,
        "party": [{"species": species, "level": revived_level}]
    })

func _fit_compact_dig_label(label: Label) -> void:
    var compact := label.get_line_count() > 3
    label.add_theme_constant_override("line_spacing", -3 if compact else 0)
    label.position.y = 6.0 if compact else 8.0
    label.size.y = 36.0 if compact else 34.0

func _on_dig_reward_collected(items: Dictionary, grant_items: bool = true) -> void:
    if is_instance_valid(coop_game) and coop_game.active and coop_game.building.collect(items):return
    if world.get_meta("ball_action_reward", false) or world.active_field_move != "DIG":
        _on_material_bundle_collected(items,grant_items)
        return
    var lines: Array[String] = []
    for raw_name in items:
        var item := ItemData.normalize_name(String(raw_name))
        var amount := int(items[raw_name])
        if grant_items:CraftingData.grant(inventory, item, amount)
        lines.append("Got x%d %s" % [amount, item])
    dig_reward_label.text = "\n".join(lines)
    _fit_compact_dig_label(dig_reward_label)
    dig_reward_seconds = 1.8
    _update_m3924_dig_hud_and_minimap(0.0)

func _on_material_collected(item_name: String, amount: int) -> void:
    if is_instance_valid(coop_game) and coop_game.active and coop_game.building.collect({ItemData.normalize_name(item_name):amount}):return
    var normalized := ItemData.normalize_name(item_name)
    CraftingData.grant(inventory, normalized, amount)
    _show_acquired_resource(normalized, amount)

func _on_material_bundle_collected(items: Dictionary, grant_items: bool = true) -> void:
    if is_instance_valid(coop_game) and coop_game.active and coop_game.building.collect(items):return
    var lines: Array[String] = ["GOT"]
    for raw_name in items.keys():
        var normalized := ItemData.normalize_name(String(raw_name))
        var amount := maxi(1, int(items[raw_name]))
        if grant_items:CraftingData.grant(inventory, normalized, amount)
        lines.append("x%d %s" % [amount, normalized])
    resource_popup_name = ""
    resource_popup_amount = 0
    resource_popup_text.text = "\n".join(lines)
    resource_popup.visible = true
    resource_popup_timer = 0.9

func _on_paint_requested(picture_index: int, cell: Vector2i) -> void:
    if int(inventory.get("THIN PAPER", 0)) <= 0:
        _show_message("PAINT needs 1 THIN PAPER.")
        return
    if is_instance_valid(coop_game) and coop_game.active:
        coop_game.building.paint(picture_index,cell)
        return
    if world.has_method("apply_paint") and bool(world.call("apply_paint", picture_index, cell)):
        inventory["THIN PAPER"] = int(inventory.get("THIN PAPER", 0)) - 1

func _on_build_requested(build_name: String, cell: Vector2i) -> void:
    var recipe := CraftingData.build_recipe(build_name)
    if recipe.is_empty():
        return
    var cost: Dictionary = recipe.get("cost", {})
    if not CraftingData.can_afford(inventory, cost):
        _show_message("Not enough materials for %s." % build_name)
        return
    if is_instance_valid(coop_game) and coop_game.active:
        coop_game.building.build(build_name,cell)
        return
    if world.place_structure(build_name, cell):
        CraftingData.consume(inventory, cost)

func _on_dig_requested(choice: String, cell: Vector2i, material: String) -> void:
    if int(inventory.get(material, 0)) <= 0:
        _show_message("DIG needs %s to place %s." % [material, choice])
        return
    if is_instance_valid(coop_game) and coop_game.active and not coop_game.building.collecting:
        coop_game.building.dig(cell,choice)
        return
    if world.has_method("apply_dig_choice"):
        if bool(world.call("apply_dig_choice", cell, choice)):
            if is_instance_valid(coop_game) and coop_game.active and coop_game.building.collecting:coop_game.building.field_choice=choice
            else:inventory[material] = int(inventory.get(material, 0)) - 1

func _on_build_refund_requested(refund: Dictionary, grant_items: bool = true) -> void:
    if refund.is_empty():
        return
    if refund.size() == 1:
        var raw_name = refund.keys()[0]
        var normalized := ItemData.normalize_name(String(raw_name))
        var amount := maxi(1, int(refund[raw_name]))
        if grant_items:CraftingData.grant(inventory, normalized, amount)
        _show_acquired_resource(normalized, amount)
        return
    var lines: Array[String] = ["GOT"]
    for raw_name in refund.keys():
        var normalized := ItemData.normalize_name(String(raw_name))
        var amount := maxi(1, int(refund[raw_name]))
        if grant_items:CraftingData.grant(inventory, normalized, amount)
        lines.append("x%d %s" % [amount, normalized])
    resource_popup_name = ""
    resource_popup_amount = 0
    resource_popup_text.text = "\n".join(lines)
    resource_popup.visible = true
    resource_popup_timer = 0.9

func _on_structure_removal_requested(cell: Vector2i, move: String) -> void:
    if move == "CUT" and not String(world.house_wall_decoration_at(cell)).is_empty():
        if is_instance_valid(coop_game) and coop_game.active:
            coop_game.building.remove_decoration(cell)
        else:
            world.remove_house_wall_decoration(cell, true)
        return
    var online: bool = is_instance_valid(coop_game) and coop_game.active
    var wipe_public := false
    if world.built_structures.has(cell):
        var build_name := String((world.built_structures[cell] as Dictionary).get("name", ""))
        # A STORAGE BOX can be cut with Pokemon in it while another one stands
        # in this world: its Pokemon stay reachable from the others. The last
        # one takes every stored Pokemon with it, so only the host may cut it,
        # and only after saying yes twice to prompts that start on NO.
        # The box itself, or boxes inside a house that go with the piece of its
        # outside being cut: the same questions either way.
        var boxes_going := 1 if build_name == "STORAGE BOX" else 0
        for inside_cell in world.house_interior_cells_behind(cell):
            if String(world.built_structures.get(inside_cell, {}).get("name", "")) == "STORAGE BOX":
                boxes_going += 1
        if boxes_going > 0 and _public_box_count() - boxes_going < 1:
            if online and not coop_game.hosting:
                _show_message("Sorry, a guest cannot cut the last public box in a world.")
                return
            if not await _ask_yes_no_starting_on_no("Last STORAGE BOX in this world!\nCut it and lose stored POKEMON?"):
                return
            if not await _ask_yes_no_starting_on_no("Are you sure? Stored POKEMON\ncannot be brought back."):
                return
            if not world.built_structures.has(cell):
                return
            wipe_public = true
    if online:
        coop_game.building.remove(cell,move,wipe_public)
        return
    if wipe_public:
        # PRIVATE CHEST contents belong to the player, not to this world.
        var private_keys: Array[String] = []
        for built_cell in world.built_structures:
            if String(world.built_structures[built_cell].get("name", "")) == "PRIVATE CHEST":
                private_keys.append(_world_storage_key(world._cell_key(built_cell),current_world_grid))
        for key in pokemon_storage.keys():
            if not String(key) in private_keys and String(key) != SHARED_STORAGE_KEY: pokemon_storage.erase(key)
    if world.has_method("remove_structure_with_field_move"):
        world.call("remove_structure_with_field_move", cell, move)

## How many public STORAGE BOXES stand in this world.
func _public_box_count() -> int:
    # Counted from the boxes that are actually built. Online the host makes
    # the same count over the whole world and has the last word.
    var count := 0
    for cell in world.built_structures:
        if String(world.built_structures[cell].get("name", "")) == "STORAGE BOX": count += 1
    # Neighbouring sections belong to a single-player world. Online the host
    # counts the whole world itself.
    if is_instance_valid(coop_game) and coop_game.active: return count
    for grid_key in adjacent_worlds:
        if grid_key == _world_grid_key(current_world_grid): continue
        for piece in adjacent_worlds[grid_key].get("state",{}).get("structures",[]):
            if piece.get("name","") == "STORAGE BOX": count += 1
    return count

## A yes/no question whose cursor starts on NO, so that pressing A through it
## answers no.
func _ask_yes_no_starting_on_no(prompt: String) -> bool:
    world.set_gameplay_enabled(false)
    # The question is only sent button presses while this is set; without it
    # the question appeared and then answered to nothing.
    var was_active := progression_active
    progression_active = true
    _show_progression_yes_no(prompt)
    progression_choice_index = 1
    _refresh_progression_yes_no()
    var result = await progression_choice_made
    _hide_progression_overlay()
    progression_active = was_active
    world.set_gameplay_enabled(not _field_ui_blocks_gameplay(build_menu_open))
    return int(result) == 1

func _world_storage_key(cell_key: String, grid: Vector2i) -> String:
    var qualified := _world_grid_key(grid) + "|" + cell_key
    # Preserve legacy boxes and their contents; never discard unqualified saves.
    if not pokemon_storage.has(qualified) and pokemon_storage.has(cell_key): return cell_key
    return qualified

func _built_storage_keys() -> Array[String]:
    var keys: Array[String] = []
    for cell in world.built_structures:
        if String(world.built_structures[cell].get("name", "")) == "STORAGE BOX":
            var key := _world_storage_key(world._cell_key(cell),current_world_grid)
            if not key in keys: keys.append(key)
    for grid_key in adjacent_worlds:
        if grid_key == _world_grid_key(current_world_grid): continue
        var pieces = String(grid_key).split(",")
        if pieces.size()!=2: continue
        var grid := Vector2i(int(pieces[0]),int(pieces[1]))
        for piece in adjacent_worlds[grid_key].get("state",{}).get("structures",[]):
            if piece.get("name","")!="STORAGE BOX": continue
            var key := _world_storage_key(world._cell_key(Vector2i(int(piece.x),int(piece.y))),grid)
            if not key in keys: keys.append(key)
    # Previously saved contents stay reachable even if the physical box was cut.
    for key in pokemon_storage:
        if String(key) != SHARED_STORAGE_KEY and not String(key) in keys: keys.append(String(key))
    keys.sort()
    if preferred_storage_box in keys:
        keys.erase(preferred_storage_box)
        keys.push_front(preferred_storage_box)
    return keys

func _route_received_pokemon(pokemon: Dictionary, allow_party: bool = true) -> String:
    # Every acquisition shares this boundary; the visible party has six slots.
    if allow_party and caught_pokemon.size() < 6:
        caught_pokemon.append(pokemon)
        pokedex_progress.mark(pokemon, true)
        return "PARTY"
    if is_instance_valid(coop_game) and coop_game.active:return coop_game.storage.route_received(pokemon)
    for key in _built_storage_keys():
        var box: Array = pokemon_storage.get(key, [])
        if POKEMON_STORAGE_CAPACITY > 0 and box.size() >= POKEMON_STORAGE_CAPACITY:
            continue
        box.append(pokemon)
        pokemon_storage[key] = box
        pokedex_progress.mark(pokemon, true)
        return "STORAGE"
    # User-requested fallback uses source SelectedMenu.releasePokemon:
    # released records are removed from ownership, not left in hidden slots.
    return "RELEASED"

func _received_pokemon_notice(pokemon: Dictionary, destination: String) -> String:
    var name := "EGG" if bool(pokemon.get("is_egg", false)) else PokemonState.display_name(pokemon).to_upper()
    if destination == "STORAGE":
        return "%s has been sent to storage." % name
    if destination == "RELEASED":
        return "You have no more room in storage! %s was released to the wild." % name
    return ""

func _recover_hidden_party_overflow() -> void:
    var stored := 0
    var released := 0
    while caught_pokemon.size() > 6:
        var pokemon: Dictionary = caught_pokemon.pop_at(6)
        var destination := _route_received_pokemon(pokemon, false)
        if destination == "STORAGE": stored += 1
        else: released += 1
    overflow_recovery_notice = ""
    if stored > 0:
        overflow_recovery_notice = "%d hidden party entries were sent to storage." % stored
    if released > 0:
        overflow_recovery_notice = "You have no more room in storage! %d excess party entries were released to the wild." % released + (" %d were sent to storage." % stored if stored > 0 else "")

func _can_receive_overworld_pokemon() -> bool:
    if caught_pokemon.size() < 6:
        return true
    for key in _built_storage_keys():
        if POKEMON_STORAGE_CAPACITY <= 0 or (pokemon_storage.get(key, []) as Array).size() < POKEMON_STORAGE_CAPACITY:
            return true
    return false

func _on_deployed_recall_requested(cell: Vector2i, species: String, message: String) -> void:
    _on_wild_pokemon_prompt_requested(-1, species, "DEPLOYED")
    if not wild_pokemon_prompt_open or wild_pokemon_prompt_kind != "DEPLOYED":
        return
    deployed_prompt_cell = cell
    wild_dialogue_label.text = message

func _on_pokemon_recalled(pokemon_data: Dictionary) -> void:
    var destination := _route_received_pokemon(pokemon_data)
    var species := String(pokemon_data.get("species", ""))
    if not species.is_empty() and not caught_species.has(species):
        caught_species.append(species)
    world.play_source_sound("seed1")
    var notice := _received_pokemon_notice(pokemon_data, destination)
    if not notice.is_empty(): _show_message(notice)

func _on_wild_pokemon_prompt_requested(
        wild_id: int, species: String, kind: String
    ) -> void:
    if (
            wild_pokemon_prompt_open or egg_pickup_open or battle_active
            or game_menu_open or craft_menu_open or build_menu_open
            or storage_menu_open or trainer_tip_open
        ):
        return
    wild_pokemon_prompt_open = true
    wild_pokemon_prompt_stage = 0
    wild_pokemon_prompt_index = 0
    wild_pokemon_prompt_id = wild_id
    wild_pokemon_prompt_species = PokemonData.battle_display_name(species).replace("_", " ")
    wild_pokemon_prompt_kind = kind.to_upper()
    # Friendly, but still shaken by a failed catch: same choice, other words.
    var frightened := wild_pokemon_prompt_kind == "FRIGHTENED"
    if frightened: wild_pokemon_prompt_kind = "FRIENDLY"
    wild_pokemon_prompt_confirm_armed = false
    world.set_gameplay_enabled(false)
    message_panel.visible = false
    wild_dialogue_panel.visible = true
    wild_choice_panel.visible = false
    wild_dialogue_arrow.visible = true
    if wild_pokemon_prompt_kind == "FRIENDLY":
        wild_dialogue_label.text = ("%s is frightened." if frightened else "%s seems friendly.") % wild_pokemon_prompt_species
    elif wild_pokemon_prompt_kind == "PROVOKED":
        wild_dialogue_label.text = "%s was provoked!" % wild_pokemon_prompt_species
        _schedule_wild_pokemon_prompt_resolution(wild_id, "PROVOKED", 0.325)
    else:
        # PROVOKE_WARNING (and legacy PROVOKE) is a complete first interaction.
        # The opening A must be released before the warning can be dismissed.
        wild_dialogue_label.text = "%s seems aggressive... it may attack if provoked!" % wild_pokemon_prompt_species
        # Source DisplayText waits for a fresh confirm before closing.

func _schedule_wild_pokemon_prompt_resolution(
        wild_id: int, kind: String, delay: float
    ) -> void:
    var timer := get_tree().create_timer(delay)
    timer.timeout.connect(
        Callable(self, "_finish_wild_pokemon_prompt_resolution").bind(
            wild_id, kind
        )
    )

func _finish_wild_pokemon_prompt_resolution(wild_id: int, kind: String) -> void:
    # Timers are identity-checked so a stale timeout can never close or resolve
    # a later Pokemon prompt. This also gives the first box a real closed gap
    # before a second A is accepted by normal overworld interaction again.
    if (
            not wild_pokemon_prompt_open
            or wild_pokemon_prompt_id != wild_id
            or wild_pokemon_prompt_kind != kind
        ):
        return
    if kind in ["PROVOKE", "PROVOKE_WARNING"]:
        if world.has_method("mark_wild_provocation_warning"):
            world.call("mark_wild_provocation_warning", wild_id)
        _close_wild_pokemon_prompt()
        return
    if kind == "PROVOKED":
        _close_wild_pokemon_prompt()
        if world.has_method("confirm_wild_provocation"):
            world.call("confirm_wild_provocation", wild_id)

func _show_friendly_party_choice() -> void:
    wild_pokemon_prompt_stage = 1
    wild_pokemon_prompt_index = 0
    wild_dialogue_label.text = "Add %s to your party?" % wild_pokemon_prompt_species
    wild_dialogue_arrow.visible = false
    wild_choice_panel.visible = true
    _update_wild_pokemon_prompt_cursor()

func _update_wild_pokemon_prompt_cursor() -> void:
    if wild_choice_cursor == null:
        return
    _align_menu_tick(wild_choice_cursor, wild_choice_panel.get_node("Yes" if wild_pokemon_prompt_index == 0 else "No"))

func _close_wild_pokemon_prompt(restore_gameplay: bool = true) -> void:
    wild_pokemon_prompt_open = false
    wild_pokemon_prompt_stage = 0
    wild_pokemon_prompt_index = 0
    wild_pokemon_prompt_id = -1
    wild_pokemon_prompt_species = ""
    wild_pokemon_prompt_kind = ""
    wild_pokemon_prompt_confirm_armed = false
    if wild_dialogue_panel != null:
        wild_dialogue_panel.visible = false
    if wild_choice_panel != null:
        wild_choice_panel.visible = false
    if (
            restore_gameplay and started and not battle_active
            and not game_menu_open and not craft_menu_open
            and not build_menu_open and not storage_menu_open
            and not trainer_tip_open and not egg_pickup_open
        ):
        world.set_gameplay_enabled(true)

func _recruit_friendly_wild(wild_id: int, species: String) -> void:
    if not world.has_method("take_friendly_wild"):
        _close_wild_pokemon_prompt()
        return
    if not _can_receive_overworld_pokemon():
        _close_wild_pokemon_prompt()
        _show_message("Your party and storage are full.")
        return
    # Online the host keeps the record of every wild Pokemon. It is claimed and
    # then reported as taken, exactly as a capture in battle is. Taking it from
    # this game alone left it on the host: it came back in the field and could
    # be taken again and again.
    var online: bool = is_instance_valid(coop_game) and coop_game.active
    if online:
        _close_wild_pokemon_prompt(false)
        if not await coop_game.wild.reserve(wild_id):
            if coop_game.active and not battle_active:
                world.set_gameplay_enabled(not _field_ui_blocks_gameplay(build_menu_open))
            return
        coop_game.wild.applying = true
    var record = world.call("take_friendly_wild", wild_id)
    if online:
        coop_game.wild.applying = false
    if typeof(record) != TYPE_DICTIONARY or (record as Dictionary).is_empty():
        if online:
            var claimed_area := String(coop_game.wild.encounter.get("area", ""))
            coop_game.wild.encounter.clear()
            coop_game.wild.original_profile.clear()
            await coop_game.command("wild_release", {"area":claimed_area, "wild_id":wild_id})
            if coop_game.active:
                world.set_gameplay_enabled(not _field_ui_blocks_gameplay(build_menu_open))
        _close_wild_pokemon_prompt()
        return
    var source := (record as Dictionary).duplicate(true)
    var nested_source = source.get("source_record", {})
    if typeof(nested_source) == TYPE_DICTIONARY:
        for raw_key in (nested_source as Dictionary).keys():
            var key := String(raw_key)
            if not source.has(key):
                source[key] = (nested_source as Dictionary)[raw_key]
    for ecology_key in [
            "source_record", "x", "y", "id", "home_biome", "burrowed",
            "move_timer", "anim_phase", "warned", "aggro_player",
            "provocation_count", "provocation_limit", "fed_until",
            "flee_steps", "charmed", "lay_egg_seconds"
        ]:
        source.erase(ecology_key)
    var normalized_species := String(
        source.get("species", species.to_lower())
    ).to_lower()
    var pokemon := BattleEngine.make_pokemon(
        normalized_species, maxi(1, int(source.get("level", 2))), null, source
    )
    var destination := _route_received_pokemon(pokemon)
    if not caught_species.has(normalized_species):
        caught_species.append(normalized_species)
    if online and not await coop_game.wild.finish_encounter("captured"):
        return
    _close_wild_pokemon_prompt()
    world.play_source_sound("seed1")
    var notice := _received_pokemon_notice(pokemon, destination)
    if not notice.is_empty(): _show_message(notice)

func _handle_wild_pokemon_prompt_input(event: InputEvent) -> void:
    if wild_pokemon_prompt_kind in ["PROVOKE", "PROVOKE_WARNING", "PROVOKED"]:
        if not wild_pokemon_prompt_confirm_armed:
            if event.is_action_released("confirm") or event.is_action_released("start"):
                wild_pokemon_prompt_confirm_armed = true
                get_viewport().set_input_as_handled()
            return
        if event.is_action_pressed("confirm") or event.is_action_pressed("start"):
            _finish_wild_pokemon_prompt_resolution(wild_pokemon_prompt_id,wild_pokemon_prompt_kind)
            get_viewport().set_input_as_handled()
        return

    # Friendly recruitment keeps its normal explicit A-driven dialogue flow,
    # but still requires release of the opening interaction first.
    if not wild_pokemon_prompt_confirm_armed:
        if event.is_action_released("confirm") or event.is_action_released("start"):
            wild_pokemon_prompt_confirm_armed = true
            get_viewport().set_input_as_handled()
        return

    if wild_pokemon_prompt_stage == 0:
        if event.is_action_pressed("confirm") or event.is_action_pressed("start"):
            _show_friendly_party_choice()
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("cancel"):
            _close_wild_pokemon_prompt()
            get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
        wild_pokemon_prompt_index = 1 - wild_pokemon_prompt_index
        _update_wild_pokemon_prompt_cursor()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("cancel"):
        _close_wild_pokemon_prompt()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("confirm") or event.is_action_pressed("start"):
        var chosen_id := wild_pokemon_prompt_id
        var chosen_species := wild_pokemon_prompt_species
        if wild_pokemon_prompt_index == 0:
            if wild_pokemon_prompt_kind == "DEPLOYED":
                var cell := deployed_prompt_cell
                _close_wild_pokemon_prompt()
                if world.deployed_pokemon.has(cell):
                    world._recall_deployed_pokemon(cell, world.deployed_pokemon[cell])
            else:
                _recruit_friendly_wild(chosen_id, chosen_species)
        else:
            _close_wild_pokemon_prompt()
        get_viewport().set_input_as_handled()

func _handle_mansion_switch_input(event: InputEvent) -> void:
    if mansion_switch_stage == 3:
        if event.is_action_pressed("confirm") or event.is_action_pressed("start"):
            mansion_switch_stage = 2
            mansion_switch_answered.emit(true)
            get_viewport().set_input_as_handled()
        return
    if mansion_switch_stage == 2:
        return
    if event.is_action_pressed("cancel"):
        mansion_switch_stage = 2
        mansion_switch_answered.emit(false)
    elif mansion_switch_stage == 0 and (event.is_action_pressed("confirm") or event.is_action_pressed("start")):
        mansion_switch_stage = 1
        egg_dialogue_arrow.hide()
        egg_choice_panel.show()
        _align_menu_tick(egg_choice_cursor, egg_choice_panel.get_node("Yes"))
    elif mansion_switch_stage == 1:
        if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
            mansion_switch_index = 1 - mansion_switch_index
            _align_menu_tick(egg_choice_cursor, egg_choice_panel.get_node("Yes" if mansion_switch_index == 0 else "No"))
        elif event.is_action_pressed("confirm") or event.is_action_pressed("start"):
            mansion_switch_stage = 2
            mansion_switch_answered.emit(mansion_switch_index == 0)
        else:
            return
    else:
        return
    get_viewport().set_input_as_handled()

func _on_egg_pickup_prompt_requested(cell: Vector2i) -> void:
    if egg_pickup_open or battle_active or game_menu_open or craft_menu_open or build_menu_open:
        return
    egg_pickup_open = true
    egg_pickup_stage = 0
    egg_pickup_index = 0
    egg_pickup_cell = cell
    world.set_gameplay_enabled(false)
    message_panel.visible = false
    egg_dialogue_panel.visible = true
    egg_choice_panel.visible = false
    egg_dialogue_label.text = "Hey!  A POKéMON\negg!"
    egg_dialogue_arrow.visible = true

func _show_egg_pickup_choice() -> void:
    egg_pickup_stage = 1
    egg_pickup_index = 0
    egg_dialogue_label.text = "Pick it up?"
    egg_dialogue_arrow.visible = false
    egg_choice_panel.visible = true
    _update_egg_pickup_cursor()

func _update_egg_pickup_cursor() -> void:
    if egg_choice_cursor == null:
        return
    # User-requested one-pixel upward adjustment to both egg choice ticks.
    _align_menu_tick(egg_choice_cursor, egg_choice_panel.get_node("Yes" if egg_pickup_index == 0 else "No"))

func _close_egg_pickup_prompt() -> void:
    egg_pickup_open = false
    egg_pickup_stage = 0
    egg_pickup_index = 0
    egg_pickup_cell = Vector2i(-2147483648, -2147483648)
    if egg_dialogue_panel != null:
        egg_dialogue_panel.visible = false
    if egg_choice_panel != null:
        egg_choice_panel.visible = false
    if (
            started and not battle_active and not game_menu_open
            and not craft_menu_open and not build_menu_open
            and not storage_menu_open and not trainer_tip_open
        ):
        world.set_gameplay_enabled(true)

func _handle_egg_pickup_input(event: InputEvent) -> void:
    if egg_pickup_stage == 0:
        if event.is_action_pressed("confirm") or event.is_action_pressed("start"):
            _show_egg_pickup_choice()
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("cancel"):
            _close_egg_pickup_prompt()
            get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
        egg_pickup_index = 1 - egg_pickup_index
        _update_egg_pickup_cursor()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("cancel"):
        _close_egg_pickup_prompt()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("confirm") or event.is_action_pressed("start"):
        var chosen_cell := egg_pickup_cell
        var take_egg := egg_pickup_index == 0
        _close_egg_pickup_prompt()
        if take_egg and world.has_method("confirm_wild_egg_pickup"):
            world.call("confirm_wild_egg_pickup", chosen_cell)
        get_viewport().set_input_as_handled()

func _on_egg_collected(species: String) -> void:
    var egg_record: Dictionary = {}
    if world.has_method("take_pending_egg_record"):
        egg_record = world.call("take_pending_egg_record")
    if bool(egg_record.get("dropped_party_egg", false)):
        for key in ["dropped_party_egg", "house_door", "house_floor", "x", "y"]: egg_record.erase(key)
        var destination := _route_received_pokemon(egg_record)
        world.play_source_sound("Berry_Get")
        _show_message("You picked up the EGG." if destination == "PARTY" else "The EGG was sent to storage.")
        return
    if egg_record.is_empty():
        egg_record = {
            "species": species.to_lower(),
            "egg_species": species.to_lower(),
            "level": 5,
            "hatch_cycles": maxi(
                1, int(PokemonData.info(species).get("egg_cycles", 20))
            ),
            "inherited_moves": []
        }
    species = String(egg_record.get(
        "egg_species", egg_record.get("species", species)
    )).to_lower()
    var level := maxi(1, int(egg_record.get("level", 5)))
    var cycles := maxi(1, int(egg_record.get(
        "hatch_cycles", PokemonData.info(species).get("egg_cycles", 20)
    )))
    var egg := _pokemon_from_egg_record(egg_record, species, level)
    egg["is_egg"] = true
    egg["egg_species"] = species
    egg["hatch_cycles"] = cycles
    egg["hatch_steps"] = maxi(
        1, cycles * PokemonEcology.EGG_STEP_INTERVAL - egg_step_timer
    )
    egg["hp"] = 0
    var destination := _route_received_pokemon(egg)
    world.play_source_sound("Berry_Get")
    var notice := _received_pokemon_notice(egg, destination)
    _show_message("%s received an EGG." % player_model_name.text.strip_edges() if notice.is_empty() else notice)

func _on_player_stepped() -> void:
    egg_step_timer = wrapi(
        egg_step_timer + 1, 0, PokemonEcology.EGG_STEP_INTERVAL
    )
    var advance_cycle := egg_step_timer == 0
    friendship_step_timer = wrapi(
        friendship_step_timer + 1,
        0,
        PokemonEcology.FRIENDSHIP_STEP_INTERVAL
    )
    if friendship_step_timer == 0:
        for party_index in range(caught_pokemon.size()):
            var raw_party_record = caught_pokemon[party_index]
            if typeof(raw_party_record) != TYPE_DICTIONARY:
                continue
            var party_record := raw_party_record as Dictionary
            if bool(party_record.get("is_egg", false)):
                continue
            var happiness := mini(
                PokemonEcology.MAX_HAPPINESS,
                int(party_record.get(
                    "happiness", party_record.get("friendship", 70)
                )) + 1
            )
            party_record["happiness"] = happiness
            party_record["friendship"] = happiness
            caught_pokemon[party_index] = party_record
    for index in range(caught_pokemon.size()):
        if typeof(caught_pokemon[index]) != TYPE_DICTIONARY:
            continue
        var entry: Dictionary = caught_pokemon[index]
        if not bool(entry.get("is_egg", false)):
            continue
        var cycles := int(entry.get("hatch_cycles", -1))
        if cycles < 0:
            cycles = maxi(1, ceili(
                float(entry.get("hatch_steps", EGG_HATCH_STEPS))
                / float(PokemonEcology.EGG_STEP_INTERVAL)
            ))
        if advance_cycle:
            cycles = maxi(0, cycles - 1)
        entry["hatch_cycles"] = cycles
        entry["hatch_steps"] = maxi(
            0, cycles * PokemonEcology.EGG_STEP_INTERVAL - egg_step_timer
        )
        if cycles > 0:
            caught_pokemon[index] = entry
            continue
        var species := String(entry.get(
            "egg_species", entry.get("species", "pidgey")
        )).to_lower()
        var level := maxi(1, int(entry.get("level", 5)))
        var hatched := _pokemon_from_egg_record(entry, species, level)
        hatched["happiness"] = 100
        hatched["friendship"] = 100
        await _run_egg_hatch_sequence(index, hatched)
        # PlayerStanding returns after the first ready egg; another ready egg
        # is handled on a later step instead of merging hatch sequences.
        return

func _ensure_party_ecology_id(index: int) -> String:
    if index < 0 or index >= caught_pokemon.size():
        return ""
    var entry = caught_pokemon[index]
    if typeof(entry) != TYPE_DICTIONARY:
        return ""
    var record := entry as Dictionary
    var ecology_id := String(record.get("party_ecology_id", ""))
    var occupied := {}
    var duplicate := false
    for other_index in range(caught_pokemon.size()):
        var other = caught_pokemon[other_index]
        if typeof(other) != TYPE_DICTIONARY: continue
        var other_id := String(other.get("party_ecology_id", ""))
        if not other_id.is_empty(): occupied[other_id] = true
        if other_index < index and not ecology_id.is_empty() and other_id == ecology_id:
            duplicate = true
    if ecology_id.is_empty() or duplicate:
        ecology_id = "party:%d" % next_party_ecology_id
        while occupied.has(ecology_id):
            next_party_ecology_id += 1
            ecology_id = "party:%d" % next_party_ecology_id
        next_party_ecology_id += 1
        record["party_ecology_id"] = ecology_id
        caught_pokemon[index] = record
    return ecology_id

func _on_pokemon_ecology_changed(pokemon_data: Dictionary) -> void:
    var ecology_id := String(pokemon_data.get("party_ecology_id", ""))
    if ecology_id.is_empty():
        return
    for index in range(caught_pokemon.size()):
        var raw_record = caught_pokemon[index]
        if typeof(raw_record) != TYPE_DICTIONARY:
            continue
        var record := raw_record as Dictionary
        if String(record.get("party_ecology_id", "")) != ecology_id:
            continue
        for property in ["happiness", "friendship"]:
            if pokemon_data.has(property):
                record[property] = pokemon_data[property]
        caught_pokemon[index] = record
        return

func _pokemon_from_egg_record(
        egg_record: Dictionary, species: String, level: int
    ) -> Dictionary:
    var pokemon := BattleEngine.make_pokemon(species, level, battle_rng, egg_record)
    # This helper produces the hatched Pokemon. Egg collection adds its egg
    # markers again afterward, while actual hatching must not retain them.
    for egg_property in ["is_egg", "egg_species", "hatch_cycles", "hatch_steps"]:
        pokemon.erase(egg_property)
    for property in [
            "gender", "shiny", "is_shiny", "generation",
            "parent_ids", "inherited_moves", "personality", "nature",
            "ability_slot", "ivs", "evs", "original_trainer", "trainer_id",
            "met_level", "met_location", "pokeball", "ribbons", "markings", "pokerus"
        ]:
        if egg_record.has(property):
            pokemon[property] = egg_record[property]
    if egg_record.has("shiny") or egg_record.has("is_shiny") or egg_record.has("isShiny"):
        pokemon["shiny"] = PokemonData.is_shiny(egg_record)
        pokemon["is_shiny"] = bool(pokemon["shiny"])

    var moves: Array[String] = []
    for raw_move in pokemon.get("moves", []):
        moves.append(String(raw_move).to_upper().replace(" ", "_"))
    var inherited_index := moves.size() if moves.size() < 4 else 0
    var inherited = egg_record.get("inherited_moves", [])
    if typeof(inherited) == TYPE_ARRAY:
        for raw_move in inherited:
            var move := String(raw_move).to_upper().replace(" ", "_")
            if PokemonData.move_info(move).is_empty() or moves.has(move):
                continue
            if moves.size() < 4:
                moves.append(move)
            else:
                moves[inherited_index] = move
            inherited_index = (inherited_index + 1) % 4
    pokemon["moves"] = moves
    var pp := {}
    for move in moves:
        pp[move] = int(PokemonData.move_info(move).get("pp", 35))
    pokemon["pp"] = pp
    pokemon["hp"] = maxi(1, int(pokemon.get("max_hp", 1)))
    pokemon["status"] = ""
    pokemon["status_counter"] = 0
    pokemon["toxic_counter"] = 0
    return pokemon

func _create_sign_editor() -> void:
    sign_dialog = ConfirmationDialog.new()
    var sign_theme := Theme.new()
    sign_theme.default_font = JOHTO_FONT
    sign_theme.default_font_size = 10
    sign_dialog.theme = sign_theme
    sign_dialog.title = "Write on the sign"
    sign_dialog.exclusive = true
    sign_dialog.ok_button_text = "WRITE"
    sign_edit = LineEdit.new()
    sign_edit.placeholder_text = "Sign text"
    sign_edit.max_length = 64
    sign_edit.position = Vector2(12, 18)
    sign_edit.size = Vector2(236, 30)
    sign_dialog.add_child(sign_edit)
    $UI.add_child(sign_dialog)
    sign_dialog.confirmed.connect(_confirm_sign_text)

func _confirm_sign_text() -> void:
    if sign_edit_mode == "BEACON":
        if world.has_method("set_structure_beacon_label"):
            world.call("set_structure_beacon_label", sign_edit_cell, sign_edit.text)
        return
    if world.has_method("set_structure_sign_text"):
        world.call("set_structure_sign_text", sign_edit_cell, sign_edit.text)

func _storage_entry_text(pokemon: Dictionary) -> String:
    if bool(pokemon.get("is_egg", false)):
        return "EGG"
    var display := PokemonState.display_name(pokemon).replace("_", " ").to_upper()
    return "%s  L%d" % [display, int(pokemon.get("level", 1))]


func _open_storage_menu(box_key: String) -> void:
    if is_instance_valid(coop_game) and coop_game.active:
        # Preparing has the host pack and save the whole area and send every
        # shared record back, which took seconds and stalled the host. It is
        # only needed for a box the shared world does not know yet.
        if not coop_game.storage.known(_world_storage_key(box_key,current_world_grid)):
            if not await coop_game.storage.prepare():_show_message("ONLINE STORAGE COULD NOT LOAD.");return
    var shared_chest: bool = not (is_instance_valid(coop_game) and coop_game.active) and \
        String(world.built_structures.get(world._cell_from_key(box_key), {}).get("name", "")) == "PRIVATE CHEST"
    box_key = SHARED_STORAGE_KEY if shared_chest else _world_storage_key(box_key,current_world_grid)
    storage_pooled = false
    storage_box_key = box_key
    if is_instance_valid(coop_game) and coop_game.active:coop_game.storage.refresh()
    # A Pokemon caught with a full party goes to the last STORAGE BOX used,
    # never to the SHARED chest.
    if not shared_chest: preferred_storage_box = box_key
    if not pokemon_storage.has(storage_box_key):
        pokemon_storage[storage_box_key] = []
    storage_column = 0
    storage_index = 0
    storage_box_window_start = 0
    storage_mode = "LIST"
    storage_switch_from = -1
    storage_menu_open = true
    storage_menu.visible = true
    message_panel.visible = false
    world.set_gameplay_enabled(false)
    touch_controls.set_game_active(true)
    _refresh_storage_menu()


func _open_pooled_storage_menu() -> void:
    # Opening the worldwide view must not change the last physical box used.
    storage_pooled = true
    storage_box_key = ""
    if is_instance_valid(coop_game) and coop_game.active: coop_game.storage.refresh()
    storage_column = 1
    storage_index = 0
    storage_box_window_start = 0
    storage_mode = "LIST"
    storage_switch_from = -1
    storage_menu_open = true
    game_menu_box.hide()
    storage_menu.show()
    message_panel.hide()
    world.set_gameplay_enabled(false)
    _refresh_storage_menu()

func _storage_pool_locations() -> Array:
    var locations: Array = []
    var keys: Array = pokemon_storage.keys()
    keys.sort()
    for key in keys:
        # The SHARED chest is opened only at a SHARED chest.
        if String(key) == SHARED_STORAGE_KEY and not (is_instance_valid(coop_game) and coop_game.active): continue
        for index in range(pokemon_storage[key].size()):
            locations.append([key, index])
    if is_instance_valid(coop_game) and coop_game.active and not coop_game.storage.sort_mode.is_empty():
        locations.sort_custom(func(a,b):return coop_game.storage.sort_less(pokemon_storage[a[0]][a[1]],pokemon_storage[b[0]][b[1]]))
    return locations

func _storage_deposit_key() -> String:
    if not storage_pooled:
        return storage_box_key
    if not preferred_storage_box.is_empty() and pokemon_storage.has(preferred_storage_box):
        return preferred_storage_box
    var keys := _built_storage_keys()
    if not keys.is_empty():
        return keys[0]
    var saved: Array = pokemon_storage.keys()
    saved.sort()
    return String(saved[0]) if not saved.is_empty() else ""

func _storage_entries() -> Array:
    if storage_column == 0:
        return caught_pokemon
    if not storage_pooled:
        return pokemon_storage.get(storage_box_key, [])
    var entries: Array = []
    for location in _storage_pool_locations():
        entries.append(pokemon_storage[location[0]][location[1]])
    return entries

func _storage_swap(first: int, second: int) -> void:
    if is_instance_valid(coop_game) and coop_game.active and storage_column==1:
        await coop_game.storage.swap(second)
        return
    if storage_pooled and storage_column == 1:
        var locations := _storage_pool_locations()
        var a: Array = locations[first]
        var b: Array = locations[second]
        var previous = pokemon_storage[a[0]][a[1]]
        pokemon_storage[a[0]][a[1]] = pokemon_storage[b[0]][b[1]]
        pokemon_storage[b[0]][b[1]] = previous
    else:
        var entries := _storage_entries()
        var previous = entries[first]
        entries[first] = entries[second]
        entries[second] = previous

func _refresh_storage_menu() -> void:
    if not storage_menu_open:
        return
    var entries := _storage_entries()
    storage_index = clampi(storage_index, 0, maxi(0, entries.size() - 1))
    storage_box_window_start = clampi(storage_box_window_start,
        maxi(0, storage_index - 5), storage_index)
    _refresh_party_list_rows(storage_rows,
        entries.slice(storage_box_window_start, storage_box_window_start + 6),
        storage_index - storage_box_window_start)
    for row_index in range(storage_rows.size()):
        var row: Dictionary = storage_rows[row_index]
        var skill_label: Label = row.field_moves
        var entry_index := storage_box_window_start + row_index
        skill_label.text = ""
        if entry_index == storage_index and entry_index < entries.size() and not entries[entry_index].get("is_egg",false):
            var pokemon: Dictionary = entries[entry_index]
            skill_label.text = " / ".join(FieldMoveData.field_moves_for(String(pokemon.species),String(pokemon.get("form",""))))
            var width := skill_label.get_theme_font("font").get_string_size(skill_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x
            skill_label.scale.x = minf(1.0,132.0/maxf(1.0,width))
        row.status.visible = skill_label.text.is_empty()
    storage_prompt.text = "Your POKéMON" if storage_column == 0 else "Stored POKéMON"
    storage_footer_arrow.position.x = 292 if storage_column == 0 else 18
    storage_footer_arrow.flip_h = storage_column == 1
    if storage_mode == "SWITCH":
        storage_prompt.text = "Switch with which POKéMON?"
    storage_actions.visible = storage_mode == "ACTION"
    var actions := _storage_actions_list()
    storage_action_index=clampi(storage_action_index,0,actions.size()-1)
    for index in range(storage_action_labels.size()):
        storage_action_labels[index].visible=index<actions.size()
        if index>=actions.size():continue
        storage_action_labels[index].position.y=9+index*(17 if actions.size()==7 else 20)
        storage_action_labels[index].text = actions[index]
    storage_choice_panel.visible = storage_mode == "CONFIRM"
    storage_choice_arrow.visible = storage_mode == "CONFIRM"
    storage_choice_label.visible = storage_mode == "CONFIRM"
    _align_menu_tick(storage_choice_arrow, storage_choice_label if storage_yes else storage_no_label)
    _align_menu_tick(storage_cursor, storage_action_labels[storage_action_index])
    storage_dialog.visible = storage_mode in ["CONFIRM", "NOTICE", "NICKNAME"]
    storage_nickname.visible = storage_mode == "NICKNAME"
    if storage_mode == "NICKNAME":
        storage_dialog_text.text = "Press enter to set"
    elif storage_mode == "CONFIRM":
        var question := "Store POKéMON of this type?" if storage_pending=="STORE TYPE" else "Move to storage?" if storage_pending == "STORE" else "Add to your party?"
        if storage_pending == "RELEASE":
            question = "Release %s to the wild? This can't be undone!" % (PokemonState.display_name(entries[storage_index]) if storage_index<entries.size() else "this POKéMON")
        elif storage_pending == "NICKNAME":
            question = "Keep changes?"
        storage_dialog_text.text = question
        storage_choice_label.text = "YES"

func _storage_notice(text: String) -> void:
    storage_mode = "NOTICE"
    storage_dialog_text.text = text
    world.call("play_source_sound", "error1")
    _refresh_storage_menu()

func _storage_is_active(pokemon: Dictionary) -> bool:
    var active: Dictionary = world.get("active_field_pokemon")
    if active.is_empty():
        return false
    var identity := String(active.get("party_ecology_id", ""))
    if not identity.is_empty():
        return identity == String(pokemon.get("party_ecology_id", ""))
    if int(active.get("ecology_id", -1)) >= 0:
        return int(active.ecology_id) == int(pokemon.get("ecology_id", -2))
    return is_same(active, pokemon)

func _storage_actions_list()->Array:
    var actions=["STORE" if storage_column==0 else "TAKE","RELEASE","NICKNAME","STATS","SWITCH","CANCEL"]
    if is_instance_valid(coop_game) and coop_game.active and storage_column==0:actions.insert(1,"STORE TYPE")
    return actions

func _storage_choose_action() -> void:
    var entries := _storage_entries()
    if entries.is_empty():
        return
    var pokemon: Dictionary = entries[storage_index]
    if is_instance_valid(coop_game) and coop_game.active:coop_game.storage.select()
    storage_pending = _storage_actions_list()[storage_action_index]
    if storage_pending == "CANCEL":
        storage_mode = "LIST"
    elif storage_pending == "STATS":
        _open_pokemon_stats(pokemon, "STORAGE")
    elif storage_pending == "SWITCH":
        storage_switch_from = storage_index
        storage_mode = "SWITCH"
    elif storage_pending == "NICKNAME":
        storage_mode = "NICKNAME"
        storage_nickname.text = PokemonState.display_name(pokemon)
        storage_nickname.call_deferred("grab_focus")
    else:
        if storage_column == 0 and storage_pending in ["STORE", "RELEASE"] and _storage_is_active(pokemon) and String(world.active_field_move) in ["SURF", "FLY"]:
            _storage_notice("Stop the field move before moving this POKéMON.")
            return
        if storage_pending in ["STORE","STORE TYPE"]:
            if _storage_deposit_key().is_empty():
                _storage_notice("Build a STORAGE BOX first.")
                return
            var healthy := false
            for index in range(entries.size()):
                if index != storage_index and not bool(entries[index].get("is_egg", false)) and int(entries[index].get("hp", 0)) > 0:
                    healthy = true
            if not healthy:
                _storage_notice("You need at least 1 healthy POKéMON in your party.")
                return
            if _storage_is_active(pokemon) and String(world.get("active_field_move")) == "SURF":
                _storage_notice("Can't store a POKéMON that's using SURF.")
                return
        elif storage_pending == "TAKE" and caught_pokemon.size() >= 6:
            _storage_notice("Your party is full!")
            return
        elif storage_pending == "RELEASE" and storage_column == 0 and entries.size() <= 1:
            _storage_notice("You need at least 1 POKéMON in your party.")
            return
        storage_yes = storage_pending != "RELEASE"
        storage_mode = "CONFIRM"
    _refresh_storage_menu()

func _storage_apply_action() -> void:
    if is_instance_valid(coop_game) and coop_game.active:
        await coop_game.storage.apply()
        return
    var entries := _storage_entries()
    if entries.is_empty():
        return
    var pokemon: Dictionary = entries[storage_index]
    if storage_pending == "NICKNAME":
        pokemon["nickname"] = storage_nickname.text
        world.call("play_source_sound", "coin1")
        return
    if storage_column == 0 and _storage_is_active(pokemon):
        world.call("clear_active_field_move", true)
    if storage_pooled and storage_column == 1:
        var location: Array = _storage_pool_locations()[storage_index]
        pokemon_storage[location[0]].remove_at(location[1])
    else:
        entries.remove_at(storage_index)
    if storage_pending == "STORE":
        var destination := _storage_deposit_key()
        var box: Array = pokemon_storage.get(destination, [])
        box.append(pokemon)
        pokemon_storage[destination] = box
    elif storage_pending == "TAKE":
        caught_pokemon.append(pokemon)
    if storage_pending != "RELEASE":
        world.call("play_source_sound", "ball_switch1")
    else:
        _play_pokemon_cry(pokemon)

func _handle_storage_menu_input(event: InputEvent) -> void:
    if is_instance_valid(coop_game) and coop_game.active and coop_game.storage.handle_key(event):
        get_viewport().set_input_as_handled();return
    if is_instance_valid(coop_game) and coop_game.active and coop_game.storage.busy:
        get_viewport().set_input_as_handled();return
    if pokemon_stats_open:
        _handle_pokemon_stats_input(event)
        return
    if storage_mode == "NICKNAME":
        if event.is_action_pressed("cancel") and not (event is InputEventKey and event.unicode > 0):
            storage_nickname.release_focus()
            storage_mode = "LIST"
            _refresh_storage_menu()
        return
    if event.is_action_pressed("cancel") or event.is_action_pressed("start"):
        if storage_mode == "LIST":
            _close_storage_menu()
        else:
            storage_mode = "LIST"
            storage_switch_from = -1
            _refresh_storage_menu()
    elif storage_mode == "NOTICE":
        if event.is_action_pressed("confirm"):
            storage_mode = "LIST"
            _refresh_storage_menu()
    elif storage_mode == "CONFIRM":
        if event.is_action_pressed("move_up") or event.is_action_pressed("move_left"):
            storage_yes = true
        elif event.is_action_pressed("move_down") or event.is_action_pressed("move_right"):
            storage_yes = false
        elif event.is_action_pressed("confirm"):
            if storage_yes:
                await _storage_apply_action()
            if storage_mode!="NOTICE":storage_mode = "LIST"
        _refresh_storage_menu()
    elif storage_mode == "ACTION":
        if event.is_action_pressed("move_up"):
            storage_action_index = maxi(0, storage_action_index - 1)
        elif event.is_action_pressed("move_down"):
            storage_action_index = mini(_storage_actions_list().size()-1, storage_action_index + 1)
        elif event.is_action_pressed("confirm"):
            _storage_choose_action()
        _refresh_storage_menu()
    else:
        var entries := _storage_entries()
        if storage_mode == "LIST" and (event.is_action_pressed("move_left") or event.is_action_pressed("move_right")):
            storage_column = 0 if event.is_action_pressed("move_left") else 1
            storage_index = 0
            storage_box_window_start = 0
            world.call("play_source_sound", "menu_switch2")
        elif event.is_action_pressed("move_up"):
            storage_index = maxi(0, storage_index - 1)
        elif event.is_action_pressed("move_down"):
            storage_index = mini(maxi(0, entries.size() - 1), storage_index + 1)
        elif event.is_action_pressed("confirm") and not entries.is_empty():
            if storage_mode == "SWITCH":
                await _storage_swap(storage_switch_from, storage_index)
                storage_switch_from = -1
                if storage_mode!="NOTICE":storage_mode = "LIST"
            else:
                storage_mode = "ACTION"
                storage_action_index = 0
        _refresh_storage_menu()
    get_viewport().set_input_as_handled()


func _close_storage_menu() -> void:
    if storage_pooled and game_menu_open:
        game_menu_box.show()
        _update_game_menu_cursor()
    var was_pooled := storage_pooled
    storage_pooled = false
    storage_menu_open = false
    storage_menu.visible = false
    if was_pooled and is_instance_valid(coop_game) and coop_game.active: coop_game.storage.refresh()
    storage_box_key = ""
    storage_column = 0
    storage_index = 0
    storage_box_window_start = 0
    if (
            started
            and not battle_active
            and not game_menu_open
            and not craft_menu_open
            and not build_menu_open
            and not trainer_tip_open
        ):
        world.set_gameplay_enabled(true)


func _on_structure_action(action: String) -> void:
    if action.begins_with("PLANT_HOLE:"):
        _open_planting_bag(Vector2i(int(action.get_slice(":",1)), int(action.get_slice(":",2))))
    elif action == "SHORE_SURF":
        await _prompt_shore_surf()
    elif action == "DRESSER":
        _next_color()
        _apply_world_player_textures()
        _show_message("Changed outfit color to %s." % PLAYER_COLOR_NAMES[player_color_index])
    elif action == "VANITY":
        _next_color()
        _apply_world_player_textures()
        _show_message("The VANITY changed your appearance to %s." % PLAYER_COLOR_NAMES[player_color_index])
    elif action.begins_with("BED:"):
        await _prompt_bed_rest(Vector2i(int(action.get_slice(":",1)),int(action.get_slice(":",2))))
    elif action.begins_with("STORAGE:"):
        _open_storage_menu(action.trim_prefix("STORAGE:"))
    elif action.begins_with("SIGN_EDIT:"):
        var parts := action.split(":", true, 3)
        if parts.size() >= 4:
            sign_edit_mode = "SIGN"
            sign_dialog.title = "Write on the sign"
            sign_edit.placeholder_text = "Sign text"
            sign_edit_cell = Vector2i(int(parts[1]), int(parts[2]))
            sign_edit.text = String(parts[3])
            sign_dialog.popup_centered(Vector2i(260, 104))
            sign_edit.grab_focus()
    elif action.begins_with("BEACON_EDIT:"):
        var beacon_parts := action.split(":", true, 3)
        if beacon_parts.size() >= 4:
            sign_edit_mode = "BEACON"
            sign_dialog.title = "Name the BEACON"
            sign_edit.placeholder_text = "Beacon name"
            sign_edit_cell = Vector2i(int(beacon_parts[1]), int(beacon_parts[2]))
            sign_edit.text = String(beacon_parts[3])
            sign_dialog.popup_centered(Vector2i(260, 104))
            sign_edit.grab_focus()
    elif action.begins_with("MANSION_SWITCH:"):
        var parts := action.split(":")
        if parts.size() != 3 or mansion_switch_open or _field_ui_blocks_gameplay():
            return
        mansion_switch_open = true
        mansion_switch_stage = 0
        mansion_switch_index = 0
        world.set_gameplay_enabled(false)
        message_panel.hide()
        egg_dialogue_label.text = "A hidden switch! Press it?"
        egg_dialogue_arrow.show()
        egg_dialogue_panel.show()
        egg_choice_panel.hide()
        var pressed: bool = await mansion_switch_answered
        egg_dialogue_panel.hide()
        egg_choice_panel.hide()
        await get_tree().create_timer((20.0 if pressed else 3.0) / 60.0).timeout
        if pressed:
            world.play_source_sound("enter1")
            SourceMansionRuntime.press_switch(world, Vector2i(int(parts[1]), int(parts[2])))
        mansion_switch_open = false
        world.set_gameplay_enabled(not _field_ui_blocks_gameplay())
    elif action.begins_with("MANSION_LOCK:"):
        if int(inventory.get("SECRET KEY", 0)) <= 0:
            _show_message("It's locked...")
            return
        var parts := action.split(":")
        if parts.size() != 3:
            return
        var cell := Vector2i(int(parts[1]), int(parts[2]))
        # In a shared world the opened door is opened for every player, and
        # the host records it, so it stays open for players who join later.
        if is_instance_valid(coop_game) and coop_game.active:
            if not await coop_game.building.share_tile_change(cell, {"kind": "MANSION_DOOR"}):
                _show_message("The door would not open. Try again.")
                return
        if world.unlock_mansion_door(cell):
            inventory["SECRET KEY"] = int(inventory.get("SECRET KEY", 0)) - 1
            _show_message("The SECRET KEY opened the door!")
    elif action.begins_with("ODD_KEYSTONE:"):
        var parts := action.split(":")
        if parts.size() != 4:
            return
        var cell := Vector2i(int(parts[1]), int(parts[2]))
        var remaining := maxi(0, int(parts[3]))
        var available := int(inventory.get("LIFE FORCE", 0))
        if available <= 0:
            _show_message("A voice whispers from within... bring %d..." % remaining)
            return
        var used := int(world.call("add_keystone_life_force", cell, mini(available, remaining)))
        inventory["LIFE FORCE"] = maxi(0, available - used)

func _on_item_collected(item_name: String) -> void:
    if is_instance_valid(coop_game) and coop_game.active and coop_game.building.collect({ItemData.normalize_name(item_name):1}):return
    if String(world.get("active_field_move")) == "DIG":
        _on_dig_reward_collected({item_name:1})
        return
    CraftingData.grant(inventory, ItemData.normalize_name(item_name), 1)
    var normalized := ItemData.normalize_name(item_name)
    _show_acquired_resource(normalized, 1)

func _show_acquired_resource(item_name: String, amount: int) -> void:
    if resource_popup.visible and resource_popup_timer > 0.0 and resource_popup_name == item_name:
        resource_popup_amount += amount
    else:
        resource_popup_name = item_name
        resource_popup_amount = amount
    resource_popup_text.text = "GOT\nx%d %s" % [
        resource_popup_amount, resource_popup_name
    ]
    resource_popup.visible = true
    resource_popup_timer = 0.9


func _open_quit_prompt() -> void:
    if generating or field_item_busy:
        return
    if field_move_wheel_open:
        _close_field_move_wheel(false)
    quit_prompt_open = true
    quit_prompt_stage = 0
    quit_prompt_index = 0
    quit_prompt_title.text = "QUIT GAME?"
    quit_prompt.visible = true
    if started:
        world.set_gameplay_enabled(false)
        touch_controls.set_game_active(true)
    _update_quit_prompt_cursor()

func _close_quit_prompt() -> void:
    quit_prompt_open = false
    quit_prompt.visible = false
    if started:
        world.set_gameplay_enabled(true)
        touch_controls.set_game_active(true)

func _update_quit_prompt_cursor() -> void:
    if quit_prompt_index == 0:
        quit_prompt_cursor.position = Vector2(32.0, 52.0)
    else:
        quit_prompt_cursor.position = Vector2(134.0, 52.0)
    _align_menu_tick(quit_prompt_cursor, quit_prompt.get_node("Yes" if quit_prompt_index == 0 else "No"))

func _handle_quit_prompt_input(event: InputEvent) -> void:
    if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
        quit_prompt_index = 1 - quit_prompt_index
        _update_quit_prompt_cursor()
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("cancel"):
        _close_quit_prompt()
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("confirm"):
        if quit_prompt_stage == 0:
            if quit_prompt_index == 1:
                _close_quit_prompt()
            else:
                # User confirmed quit. Ask whether to save before leaving.
                quit_prompt_stage = 1
                quit_prompt_index = 0
                quit_prompt_title.text = "SAVE BEFORE QUIT?"
                _update_quit_prompt_cursor()
        else:
            if quit_prompt_index == 0:
                var saved_ok = await _save_current_game_for_quit()
                if not saved_ok:
                    quit_prompt_title.text = "SAVE FAILED"
                    quit_prompt_stage = 0
                    quit_prompt_index = 1
                    _update_quit_prompt_cursor()
                    return
            set_process_input(false)
            await shared_save_folder.export_files(self)
            get_tree().quit()
        get_viewport().set_input_as_handled()

func _save_current_game_for_quit() -> bool:
    _sync_pokedex_owned()
    if not started:
        return true
    if coop_game.active:
        return await coop_game.save_game(_capture_game_save(3))
    if not _ensure_save_directory():
        return false

    var player = world.get_node("Player")
    var world_name = world_edit.text.strip_edges()
    if world_name.is_empty():
        world_name = "PokeWilds"

    var data = {
        "version": 3,
        "world_seed": int(world.get("world_seed")),
        "world_size": int(world.get("map_size_index")),
        "world_name": world_name,
        "player_name": player_model_name.text,
        "player_name_custom": not custom_player_name.is_empty(),
        "player_color": player_color_index,
        "player_model": player_model_index,
        "player_x": player.position.x,
        "player_y": player.position.y,
        "options": GameOptions.values.duplicate(),
        "waypoints": map_waypoints.duplicate(true),
        "pokedex": pokedex_progress.entries.duplicate(),
        "pokedex_shiny": pokedex_progress.shiny_entries.duplicate(),
        "caught_pokemon": caught_pokemon,
        "pokemon_storage": pokemon_storage,
        "preferred_storage_box": preferred_storage_box,
        "inventory": inventory,
        "source_key_items_initialized": true,
        "adjacent_worlds": adjacent_worlds,
        "world_grid_x": current_world_grid.x,
        "world_grid_y": current_world_grid.y,
        "crafting_state": world.get_crafting_save_state()
    }

    var save_path = _save_path_for_world(world_name)
    var file = FileAccess.open(save_path, FileAccess.WRITE)
    if file == null:
        return false

    data["storage_shared"] = true
    data["storage_serial"] = shared_storage_serial + 1
    file.store_string(JSON.stringify(data))
    file.flush()
    file.close()

    if not FileAccess.file_exists(save_path):
        return false

    _write_shared_storage()
    _write_save_index(world_name, save_path)
    _save_setup()
    world.call("play_source_sound", "save1")
    return true

func _show_touch_changed(enabled: bool) -> void:
    touch_controls.set_touch_enabled(enabled)
    _refresh_touch_config_labels()

func _auto_hide_changed(enabled: bool) -> void:
    touch_controls.set_auto_hide_controller(enabled)
    _refresh_touch_config_labels()

func _touch_opacity_changed(value: float) -> void:
    touch_controls.set_control_opacity(value / 100.0)
    _refresh_touch_config_labels()

func _touch_size_changed(value: float) -> void:
    touch_controls.set_control_scale(value / 100.0)
    _refresh_touch_config_labels()

func _cycle_touch_theme() -> void:
    touch_controls.set_theme_mode((touch_controls.theme_mode + 1) % 3)
    _refresh_touch_config_labels()
    _apply_touch_config_theme()

func _on_touch_theme_changed() -> void:
    if touch_config.visible:
        _apply_touch_config_theme()

func _refresh_touch_config_labels() -> void:
    auto_hide.text = "AUTO HIDE: %s" % ("ON" if touch_controls.auto_hide_controller else "OFF")
    show_touch.text = "TOUCH CONTROLS: %s" % (
        "ON" if touch_controls.touch_enabled else "OFF"
    )
    touch_opacity_label.text = "  OPACITY %d%%" % roundi(
        touch_controls.control_opacity * 100.0
    )
    touch_size_label.text = "  SIZE %d%%" % roundi(
        touch_controls.control_scale * 100.0
    )
    var theme_names := ["SYSTEM", "LIGHT", "DARK"]
    touch_theme_button.text = "THEME: %s" % theme_names[
        clampi(touch_controls.theme_mode, 0, theme_names.size() - 1)
    ]

func _apply_touch_config_theme() -> void:
    touch_config.add_theme_stylebox_override("panel", GameOptions.style())
    _set_touch_config_colors(touch_config, Color.BLACK)
    _style_touch_config_buttons()
    _style_touch_config_sliders()
    if touch_config_scroll == null:
        # Keep every setting reachable on smaller screens and within cutouts.
        var contents := touch_config.get_node("VBox") as VBoxContainer
        touch_config_scroll = ScrollContainer.new()
        touch_config_scroll.name = "TouchSettingsScroll"
        touch_config_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        touch_config_scroll.follow_focus = true
        touch_config.add_child(touch_config_scroll)
        contents.reparent(touch_config_scroll)
        contents.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
        contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        touch_controls.safe_area_changed.connect(_layout_touch_config)
    var scroll_bar := touch_config_scroll.get_v_scroll_bar()
    var rail := StyleBoxFlat.new();rail.bg_color=Color(0.9,0.9,0.9);rail.content_margin_left=2;rail.content_margin_right=2
    var thumb := StyleBoxFlat.new();thumb.bg_color=Color.BLACK;thumb.content_margin_left=2;thumb.content_margin_right=2
    scroll_bar.add_theme_stylebox_override("scroll",rail)
    for state in ["grabber","grabber_highlight","grabber_pressed"]:scroll_bar.add_theme_stylebox_override(state,thumb)
    _layout_touch_config()
    _prepare_swipe_cursor()

var touch_config_scroll: ScrollContainer

func _layout_touch_config(_bounds: Rect2 = Rect2()) -> void:
    if touch_config_scroll == null: return
    var bounds := touch_controls.usable_rect
    var panel_size := Vector2(minf(224.0, bounds.size.x - 8.0), minf(172.0, bounds.size.y - 8.0))
    touch_config.size = panel_size
    touch_config.position = (bounds.position + (bounds.size - panel_size) * 0.5).round()
    touch_config_scroll.position = Vector2(12, 10)
    touch_config_scroll.size = panel_size - Vector2(24, 20)

func _touch_config_box(color: Color, border: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = border
    style.set_border_width_all(1)
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    return style

func _style_touch_config_buttons() -> void:
    for node in touch_config.find_children("*", "Button", true, false):
        var button := node as Button
        button.text = button.text.to_upper()
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.custom_minimum_size.y = 16
        button.focus_mode = Control.FOCUS_NONE
        var plain := StyleBoxEmpty.new()
        plain.content_margin_left = 12
        for state in ["normal", "hover", "pressed", "focus", "disabled"]:
            button.add_theme_stylebox_override(state, plain)
        if button is CheckButton:
            var blank := ImageTexture.create_from_image(Image.create(1,1,false,Image.FORMAT_RGBA8))
            for icon_name in ["checked", "unchecked", "checked_disabled", "unchecked_disabled", "checked_mirrored", "unchecked_mirrored"]:
                button.add_theme_icon_override(icon_name, blank)

func _style_touch_config_sliders() -> void:
    var track := _touch_config_box(Color.BLACK,Color.BLACK,0)
    track.content_margin_top = 1.0
    track.content_margin_bottom = 1.0
    var fill := _touch_config_box(Color.BLACK,Color.BLACK,0)
    var grabber := GradientTexture2D.new()
    var gradient := Gradient.new()
    gradient.set_color(0,Color(0.75,0.15,0.15))
    gradient.set_color(1,Color(0.75,0.15,0.15))
    grabber.gradient = gradient
    grabber.width = 6
    grabber.height = 10
    for slider in [touch_opacity_slider,touch_size_slider]:
        slider.add_theme_stylebox_override("slider",track)
        slider.add_theme_stylebox_override("grabber_area",fill)
        slider.add_theme_stylebox_override("grabber_area_highlight",fill)
        for state in ["grabber","grabber_highlight","grabber_disabled"]:
            slider.add_theme_icon_override(state,grabber)

func _set_touch_config_colors(node: Node, color: Color) -> void:
    if node is Label or node is Button:
        var control := node as Control
        control.add_theme_font_override("font",JOHTO_FONT)
        control.add_theme_font_size_override("font_size",8)
        control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color","font_disabled_color"]:
            control.add_theme_color_override(state,color)
    for child in node.get_children():
        _set_touch_config_colors(child,color)

func _open_modding_menu() -> void:
    touch_config.hide()
    if not is_instance_valid(mod_menu_panel):
        mod_menu_panel=preload("res://scripts/modding_menu.gd").new()
        $UI.add_child(mod_menu_panel)
        mod_menu_panel.configure(self)
    mod_menu_panel.open()

func _open_game_files_menu() -> void:
    touch_config.hide()
    if not is_instance_valid(game_files_menu):
        game_files_menu=preload("res://scripts/game_files_menu.gd").new()
        $UI.add_child(game_files_menu)
        game_files_menu.configure(self)
    game_files_menu.open()

func _open_touch_config(from_options: bool = false) -> void:
    if not from_options and not _is_android_touch_runtime():
        touch_config.visible = false
        touch_controls.set_game_active(false)
        return
    if touch_controls.edit_mode:
        touch_controls.end_edit()
    if field_move_wheel_open:
        _close_field_move_wheel(false)
    touch_config.visible = true
    swipe_stick_held = false
    _position_swipe_cursor.call_deferred()
    touch_controls.set_game_active(false)
    show_touch.button_pressed = touch_controls.touch_enabled
    auto_hide.button_pressed = touch_controls.auto_hide_controller
    touch_opacity_slider.set_value_no_signal(
        touch_controls.control_opacity * 100.0
    )
    touch_size_slider.set_value_no_signal(
        touch_controls.control_scale * 100.0
    )
    _refresh_touch_config_labels()
    _apply_touch_config_theme()
    if started:
        world.set_gameplay_enabled(false)

func _move_controls() -> void:
    touch_config.visible = false
    touch_controls.set_game_active(true)
    touch_controls.begin_edit()

func _reset_layout() -> void:
    touch_controls.reset_layout()

func _close_touch_config() -> void:
    touch_config.visible = false
    if not started:
        touch_controls.set_game_active(true)
        return
    var gameplay_should_resume := (
        not battle_active
        and not game_menu_open
        and not craft_menu_open
        and not quit_prompt_open
    )
    world.set_gameplay_enabled(gameplay_should_resume)
    touch_controls.set_game_active(true)

func _set_fitting_pokemon_name(label: Label, record: Dictionary, override_text: String = "") -> void:
    if not label.has_meta("original_name_overrun"):
        label.set_meta("original_name_overrun", label.text_overrun_behavior)
        label.set_meta("original_name_clip", label.clip_text)
    var mega_name := String(record.get("species", "")) in ["mega_charizard_x", "mega_charizard_y", "mega_venusaur", "mega_blastoise", "mega_gyarados", "mega_sharpedo", "mega_kangaskhan"]
    # Fit the full X/Y suffix before drawing; Label ellipsis runs before scale.
    label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if mega_name else int(label.get_meta("original_name_overrun"))
    label.clip_text = false if mega_name else bool(label.get_meta("original_name_clip"))
    var full_name := PokemonState.display_name(record).to_upper() if override_text.is_empty() else override_text
    label.text = full_name
    var width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
    label.scale.x = minf(1.0, label.size.x / maxf(1.0, width))

func _party_record_frame(row_data: Dictionary) -> Texture2D:
    var species := String(row_data.get("species", ""))
    var community_key := "mega_gengar" if species == "gengar" and String(row_data.get("form", "")) == "mega" else species
    var community := preload("res://scripts/divinakra_mega_art.gd").texture(community_key, "menu", PokemonData.is_shiny(row_data))
    if community != null:
        return _source_texture_region(community, Rect2((4 + party_sprite_animation_frame % 2) * 16, 0, 16, 16))
    if species == "gengar" and String(row_data.get("form", "")) == "mega":
        var sheet := PokemonData.record_texture(row_data, "overworld")
        return _source_texture_region(sheet, Rect2((4 + party_sprite_animation_frame % 2) * 32, 0, 32, 32))
    return _party_overworld_frame(species, party_sprite_animation_frame, bool(row_data.get("shiny", false)))

func _party_overworld_frame(species: String, animation_frame: int = 0, shiny: bool = false) -> Texture2D:
    # Picture 2 uses the Pokemon's actual PokeWilds 16x16 overworld artwork.
    # Use each authored sheet's front-facing pair; never reuse CUT pose state.
    var texture := PokemonData.texture(species, "overworld", shiny)
    if texture == null:
        return _battle_sprite_frame(PokemonData.texture(species, "front", shiny))
    if texture.has_meta("mega_gengar_walk"):
        var mega_frame := texture.get_width() / 6.0
        return _source_texture_region(texture, Rect2((4 + animation_frame % 2) * mega_frame, 0, mega_frame, texture.get_height()))
    var front_pair := 4
    if species.to_lower() in ["krabby", "kingler"]:
        front_pair = 0
    elif species.to_lower() in ["lombre", "lotad", "shellder", "slowpoke", "growlithe_hisuian"]:
        front_pair = 2
    var frame := front_pair + clampi(animation_frame, 0, 1)
    if species.to_lower() in ["aexeggutor", "exeggutor_alolan"] and texture.get_height() == 48:
        return _source_texture_region(texture, Rect2(frame * 16, 0, 16, 48))
    if texture.get_width() >= 96 and texture.get_height() >= 16:
        return _source_texture_region(texture, Rect2(frame * 16, 0, 16, 16))
    if texture.get_height() >= 96 and texture.get_width() >= 16:
        return _source_texture_region(texture, Rect2(0, frame * 16, 16, 16))
    frame = clampi(animation_frame, 0, 1)
    if texture.get_width() >= 32 and texture.get_height() >= 16:
        return _source_texture_region(texture, Rect2(frame * 16, 0, 16, 16))
    if texture.get_height() >= 32 and texture.get_width() >= 16:
        return _source_texture_region(texture, Rect2(0, frame * 16, 16, 16))
    if texture.get_width() >= 16 and texture.get_height() >= 16:
        return _source_texture_region(texture, Rect2(0, 0, 16, 16))
    return texture

func _refresh_source_action_rows(label: Label, cursor: TextureRect,
        entries: Array, selected: int) -> void:
    var first := maxi(0, selected - 5)
    var lines: Array[String] = []
    for index in range(first, mini(first + 6, entries.size())):
        lines.append(String(entries[index]))
    label.text = "\n".join(lines)
    var font_size := label.get_theme_font_size("font_size")
    var pitch := JOHTO_FONT.get_height(font_size) + float(
        label.get_theme_constant("line_spacing"))
    cursor.position.y = roundf(label.position.y +
        float(selected - first) * pitch)

func _pokemon_stat_field(parent: Control, key: String, at: Vector2,
        dimensions: Vector2, font_size: int = 9, right: bool = false) -> Label:
    var label := _source_ui_label(parent, key, at, dimensions, font_size)
    label.clip_text = true
    if right:
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    pokemon_stats_fields[key] = label
    return label

func _pokemon_stats_border(parent: Control, at: Vector2,
        dimensions: Vector2) -> void:
    # Restore the original source-style NinePatch border. Only the unwanted
    # EXP track is removed; the stats-page frame itself remains intact.
    var border = NinePatchRect.new()
    border.texture = GameOptions.frame_texture()
    border.position = at
    border.size = dimensions
    border.patch_margin_left = 8 if int(GameOptions.values.frame) >= 2 else 10
    border.patch_margin_top = 8 if int(GameOptions.values.frame) >= 2 else 10
    border.patch_margin_right = 8 if int(GameOptions.values.frame) >= 2 else 10
    border.patch_margin_bottom = 8 if int(GameOptions.values.frame) >= 2 else 10
    border.draw_center = false
    border.mouse_filter = Control.MOUSE_FILTER_IGNORE
    border.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    parent.add_child(border)
    parent.move_child(border, 0)

func _build_pokemon_stats_pages(parent: Control) -> void:
    for index in range(3):
        var page = ColorRect.new()
        page.name = "StatsPage%d" % index
        page.position = Vector2(0, 80)
        page.size = Vector2(320, 100)
        page.color = [Color8(248, 152, 248), Color8(176, 248, 104),
            Color8(136, 240, 240)][index]
        parent.add_child(page)
        pokemon_stats_pages.append(page)

    var hp_page = pokemon_stats_pages[0]
    _source_ui_label(hp_page, "HPTitle", Vector2(14, 11), Vector2(30, 14), 9, "HP:")
    # M74.3.9.13: this is the stats page only. The source-font current/max HP
    # replaces the meter; battle and six-slot party HP bars are untouched.
    pokemon_stats_hp_fill = null
    _pokemon_stat_field(hp_page, "HP", Vector2(48, 10), Vector2(90, 14), 10, true)
    _source_ui_label(hp_page, "StatusTitle", Vector2(14, 40), Vector2(82, 14), 9, "STATUS/")
    _pokemon_stat_field(hp_page, "Status", Vector2(52, 53), Vector2(84, 14), 9, true)
    _source_ui_label(hp_page, "TypeTitle", Vector2(14, 69), Vector2(70, 14), 9, "TYPE/")
    _pokemon_stat_field(hp_page, "Types", Vector2(52, 65), Vector2(84, 24), 8, true)
    _source_ui_label(hp_page, "ExpTitle", Vector2(171, 11), Vector2(132, 14), 10, "EXP POINTS")
    _pokemon_stat_field(hp_page, "Exp", Vector2(188, 24), Vector2(112, 14), 10, true)
    _source_ui_label(hp_page, "NextTitle", Vector2(171, 42), Vector2(132, 14), 10, "LEVEL UP")
    _pokemon_stat_field(hp_page, "NextExp", Vector2(188, 58), Vector2(112, 14), 10, true)
    _pokemon_stat_field(hp_page, "NextLevel", Vector2(188, 73), Vector2(112, 14), 9, true)
    pokemon_stats_exp_fill = null
    _pokemon_stats_border(hp_page, Vector2.ZERO, Vector2(153, 100))
    _pokemon_stats_border(hp_page, Vector2(151, 0), Vector2(169, 100))

    var moves_page = pokemon_stats_pages[1]
    _source_ui_label(moves_page, "ItemTitle", Vector2(16, 12), Vector2(72, 14), 10, "ITEM")
    _pokemon_stat_field(moves_page, "Item", Vector2(104, 12), Vector2(198, 14), 10)
    _source_ui_label(moves_page, "MoveTitle", Vector2(16, 27), Vector2(72, 14), 10, "MOVE")
    for index in range(4):
        _pokemon_stat_field(moves_page, "Move%d" % index,
            Vector2(104, 27 + index * 16), Vector2(198, 15), 10)
    _pokemon_stats_border(moves_page, Vector2.ZERO, Vector2(320, 100))

    var stats_page = pokemon_stats_pages[2]
    _source_ui_label(stats_page, "IdTitle", Vector2(16, 10), Vector2(82, 14), 9, "IDNo.")
    _pokemon_stat_field(stats_page, "TrainerId", Vector2(36, 27), Vector2(102, 14), 10)
    _source_ui_label(stats_page, "OTTitle", Vector2(16, 51), Vector2(82, 14), 10, "OT/")
    _pokemon_stat_field(stats_page, "OriginalTrainer", Vector2(36, 68), Vector2(102, 18), 10)
    var keys = ["attack", "defense", "sp_attack", "sp_defense", "speed"]
    var titles = ["ATTACK", "DEFENSE", "SPCL.ATK", "SPCL.DEF", "SPEED"]
    for index in range(5):
        _source_ui_label(stats_page, "Title%d" % index,
            Vector2(171, 11 + index * 17), Vector2(104, 14), 9, titles[index])
        _pokemon_stat_field(stats_page, keys[index],
            Vector2(268, 11 + index * 17), Vector2(34, 14), 9, true)
    _pokemon_stats_border(stats_page, Vector2.ZERO, Vector2(153, 100))
    _pokemon_stats_border(stats_page, Vector2(151, 0), Vector2(169, 100))

func _setup_generation_clouds() -> void:
    var background := $UI/GenerationPanel/Background as TextureRect
    background.texture = preload("res://assets/environment/cloud5.png")
    background.stretch_mode = TextureRect.STRETCH_SCALE
    var shader := Shader.new()
    shader.code = """
shader_type canvas_item;
render_mode unshaded;
void fragment() {
    // Game.render: four one-pixel steps per 65 source ticks.
    // Rotate the loading artwork 180 degrees and scroll right-to-left.
    float tick = floor(TIME * 60.0);
    float offset = floor(tick / 65.0) * 4.0 + floor(mod(tick, 65.0) / 16.0);
    vec2 pixel = floor(UV * vec2(320.0, 180.0));
    COLOR = texture(TEXTURE, (vec2(191.0) - mod(pixel + vec2(offset, 0.0), vec2(192.0)) + 0.5) / 192.0);
}
"""
    var material_value := ShaderMaterial.new()
    material_value.shader = shader
    background.material = material_value


var mod_menu_panel: Control

const START_DOUBLE_TAP_SECONDS := 0.28
var start_menu_ticket := 0
var start_menu_pending := false
var start_menu_held := false

func _start_menu_context_available() -> bool:
    return started and not generating and not battle_active and not battle_entry_pending and not game_menu_open \
        and not wild_pokemon_prompt_open and not egg_pickup_open and not storage_menu_open \
        and not trainer_tip_open and not setup_load_open and not pokemon_stats_open \
        and not touch_config.visible and not touch_controls.edit_mode and not progression_active \
        and not field_move_wheel_open and not quit_prompt_open and not build_menu_open \
        and not craft_menu_open and (not field_item_busy or _sleeping_bag_active()) \
        and not (is_instance_valid(game_files_menu) and game_files_menu.visible) \
        and not (is_instance_valid(mod_menu_panel) and mod_menu_panel.visible)

func _queue_start_menu(event: InputEvent) -> void:
    # Start opens the ordinary menu immediately on physical and touch controls.
    if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START:
        if start_menu_held:
            return
        start_menu_held = true
    if _start_menu_context_available():
        _open_game_menu()

func _prompt_shore_surf() -> void:
    var party_index := _find_field_move_pokemon_index("SURF")
    if party_index < 0 or _field_ui_blocks_gameplay():
        return
    var target: Vector2i = world._player_cell() + world._facing_cell()
    if not world._can_prompt_shore_surf(target):
        return
    # Reuse the tested two-stage egg/switch dialogue and its exact tick offsets.
    mansion_switch_open = true
    mansion_switch_stage = 0
    mansion_switch_index = 0
    world.set_gameplay_enabled(false)
    message_panel.hide()
    egg_dialogue_label.text = "Want to SURF?"
    egg_dialogue_arrow.show()
    egg_dialogue_panel.show()
    egg_choice_panel.hide()
    var accepted: bool = await mansion_switch_answered
    egg_choice_panel.hide()
    egg_dialogue_arrow.hide()
    if accepted and world._can_prompt_shore_surf(target):
        _ensure_party_ecology_id(party_index)
        var pokemon: Dictionary = caught_pokemon[party_index]
        var name := String(pokemon.get("nickname", "")).strip_edges()
        if name.is_empty(): name = PokemonData.battle_display_name(String(pokemon.get("species", "POKEMON")))
        egg_dialogue_label.text = "%s is using SURF!" % name.to_upper()
        await get_tree().create_timer(3.0 / 60.0).timeout
        _play_pokemon_cry(pokemon)
        mansion_switch_stage = 3
        egg_dialogue_arrow.show()
        await mansion_switch_answered
        egg_dialogue_arrow.hide()
        if world.set_active_field_move(pokemon, "SURF"):
            world.present_field_move_pokemon()
            var entry := create_tween()
            entry.tween_property(world.player, "position", world._cell_center(target), 16.0 / 120.0)
            await entry.finished
    else:
        await get_tree().create_timer(10.0 / 60.0).timeout
    egg_dialogue_panel.hide()
    mansion_switch_open = false
    world.set_gameplay_enabled(not _field_ui_blocks_gameplay())

func _prompt_bed_rest(cell: Vector2i) -> void:
    if _field_ui_blocks_gameplay(): return
    mansion_switch_open = true
    mansion_switch_stage = 0
    mansion_switch_index = 0
    world.set_gameplay_enabled(false)
    message_panel.hide()
    egg_dialogue_label.text = "Do you want to sleep?"
    egg_dialogue_arrow.show()
    egg_dialogue_panel.show()
    egg_choice_panel.hide()
    var accepted: bool = await mansion_switch_answered
    egg_choice_panel.hide()
    egg_dialogue_panel.hide()
    egg_dialogue_arrow.hide()
    mansion_switch_open = false
    if accepted:
        field_item_busy = true
        await get_tree().create_timer(20.0/60.0).timeout
        if world.begin_bed_rest(cell):
            sleeping_bag_heal_accumulator = 0.0
            return
        field_item_busy = false
    world.set_gameplay_enabled(not _field_ui_blocks_gameplay())


func _world_grid_key(grid: Vector2i) -> String:
    return "%d,%d" % [grid.x, grid.y]

func _show_flying_edge_sky() -> void:
    var bounds: Rect2i = world.get_map_bounds()
    if not is_instance_valid(edge_sky):
        edge_sky = preload("res://scripts/world_boundary_water.gd").new()
        edge_sky.name = "WorldBoundaryWater"
        world.get_node("GroundLayer").add_child(edge_sky)
        edge_sky.configure(world)
    edge_sky.visible = true
    var camera = world.player.camera
    camera.limit_left = bounds.position.x*16-192
    camera.limit_top = bounds.position.y*16-192
    camera.limit_right = bounds.end.x*16+192
    camera.limit_bottom = bounds.end.y*16+192

func check_flying_map_edge() -> void:
    if not started or generating or edge_travel_busy or _field_ui_blocks_gameplay():
        return
    if world.active_area_id != "OVERWORLD" or world.active_field_move not in ["FLY","SURF"]: return
    _show_flying_edge_sky()
    var bounds: Rect2i = world.get_map_bounds()
    var cell: Vector2i = world._player_cell()
    if bounds.has_point(cell):
        if world.active_field_move != "SURF": return
        var facing: Vector2i = world._facing_cell()
        var intent: Vector2 = world.player.input_router.movement_vector()
        if bounds.has_point(cell+facing) or (world.player.velocity.dot(Vector2(facing))<=0 and intent.dot(Vector2(facing))<=0): return
        cell += facing
    var direction := Vector2i.ZERO
    if cell.x < bounds.position.x: direction = Vector2i.LEFT
    elif cell.x >= bounds.end.x: direction = Vector2i.RIGHT
    elif cell.y < bounds.position.y: direction = Vector2i.UP
    elif cell.y >= bounds.end.y: direction = Vector2i.DOWN
    edge_travel_busy = true
    world.set_gameplay_enabled(false)
    _prompt_adjacent_world.call_deferred(direction)

func _prompt_adjacent_world(direction: Vector2i) -> void:
    mansion_switch_open = true
    mansion_switch_stage = 0
    mansion_switch_index = 0
    message_panel.hide()
    egg_dialogue_label.text = "Going further will take you to a new area... keep going?"
    egg_dialogue_arrow.show()
    egg_dialogue_panel.show()
    egg_choice_panel.hide()
    var accepted: bool = await mansion_switch_answered
    egg_choice_panel.hide()
    egg_dialogue_arrow.hide()
    egg_dialogue_panel.hide()
    if accepted:
        await _travel_adjacent_world(direction)
    else:
        var bounds: Rect2i = world.get_map_bounds()
        var cell: Vector2i = world._player_cell()
        cell.x = clampi(cell.x, bounds.position.x, bounds.end.x-1)
        cell.y = clampi(cell.y, bounds.position.y, bounds.end.y-1)
        world.player.position = world._cell_center(cell)
        world.player.facing = -Vector2(direction)
        world._place_field_helper_live()
    mansion_switch_open = false
    edge_travel_busy = false
    world.set_gameplay_enabled(not _field_ui_blocks_gameplay())

func _travel_adjacent_world(direction: Vector2i) -> void:
    var online_destination:Dictionary={}
    if is_instance_valid(coop_game) and coop_game.active:
        online_destination=await coop_game.prepare_travel(current_world_grid+direction)
        if online_destination.has("error"):_show_message(String(online_destination.error));return
    var bounds: Rect2i = world.get_map_bounds()
    var cell: Vector2i = world._player_cell()
    var fraction := Vector2(cell-bounds.position)/Vector2(bounds.size)
    var mount: Dictionary = world.active_field_pokemon.duplicate(true)
    var travel_move := String(world.active_field_move)
    var elapsed: float = world.world_elapsed_seconds
    var key := _world_grid_key(current_world_grid)
    adjacent_worlds[key] = {"seed":world.world_seed,"size":world.map_size_index,"state":world.get_crafting_save_state()}
    current_world_grid += direction
    var destination: Dictionary = adjacent_worlds.get(_world_grid_key(current_world_grid), {})
    if not online_destination.is_empty():destination={} if online_destination.get("new",false) else online_destination
    var seed_value := int(destination.get("seed", 0))
    if seed_value == 0:
        var random := RandomNumberGenerator.new()
        random.randomize()
        seed_value = int(random.randi_range(1,2147483646))
    # Java chooses 40000, 50000, 54000 or 56000 radius parameters.
    var size_index := int(destination.get("size", randi_range(1,4)))
    generating = true
    var travel_view: Control
    if destination.is_empty():
        # A new area takes minutes to generate. It was shown as a plain grey
        # screen with the player hovering in it and no word of what was
        # happening, so it looked as if the game had stopped. It now has the
        # same sky, trainer tips and message as every other loading screen.
        generation_status.text = "GENERATING WORLD...\nPLEASE WAIT..."
        _show_generation_tip()
        generation_panel.show()
        await get_tree().process_frame
    else:
        generation_status.text = "LOADING...\nPLEASE WAIT...."
        generation_panel.show()
    await world.generate_world(seed_value, size_index, not destination.is_empty())
    if not world.generation_error.is_empty():
        current_world_grid -= direction
        # Preflight failure leaves the current world's terrain and items intact.
        world.player.position = world._cell_center(Vector2i(
            clampi(cell.x,bounds.position.x,bounds.end.x-1),
            clampi(cell.y,bounds.position.y,bounds.end.y-1)))
        world.player.facing = -Vector2(direction)
        # Failed preflight retains the existing mount along with the world.
        world.m3922_fly_phase = "HOVER"
        world.m3922_fly_height = 32.0
        world._place_field_helper_live()
        if is_instance_valid(travel_view): travel_view.queue_free()
        generation_panel.hide()
        generating = false
        _show_message(world.generation_error)
        return
    world.set_gameplay_enabled(false)
    if not destination.is_empty(): await world.restore_crafting_save_state(destination.state)
    world.world_elapsed_seconds = elapsed
    _apply_world_player_textures()
    bounds = world.get_map_bounds()
    cell = bounds.position + Vector2i(Vector2(bounds.size)*fraction)
    cell.x = clampi(cell.x,bounds.position.x,bounds.end.x-1)
    cell.y = clampi(cell.y,bounds.position.y,bounds.end.y-1)
    if direction == Vector2i.LEFT: cell.x = bounds.end.x-1
    elif direction == Vector2i.RIGHT: cell.x = bounds.position.x
    elif direction == Vector2i.UP: cell.y = bounds.end.y-1
    else: cell.y = bounds.position.y
    world.player.position = world._cell_center(cell)
    world.player.facing = Vector2(direction)
    if travel_move == "SURF":
        # Find water along the destination edge rather than mounting on dry land.
        var water_cell := cell
        var found := false
        for offset in range(maxi(bounds.size.x,bounds.size.y)):
            for sign_value in [1,-1]:
                var candidate: Vector2i = cell + (Vector2i.DOWN if direction.x!=0 else Vector2i.RIGHT)*offset*sign_value
                if bounds.has_point(candidate) and world.terrain_kind_at(candidate)==0:
                    water_cell=candidate;found=true;break
            if found: break
        if found: world.player.position=world._cell_center(water_cell)
    world.set_active_field_move(mount, travel_move, travel_move=="SURF")
    world.m3922_fly_phase = "HOVER"
    world.m3922_fly_height = 32.0
    world._place_field_helper_live()
    world.begin_encounter_grace()
    # Generating a new area uncovers the map around wherever the player
    # stood in the area they left, which in the new one is somewhere they
    # have never been: a lone explored circle far from where they arrive.
    if destination.is_empty(): world.discovered_cells.clear()
    world.reveal_player_area()
    _invalidate_travel_maps()
    _show_flying_edge_sky()
    world.player.camera.reset_smoothing()
    if is_instance_valid(coop_game) and coop_game.active:
        if not await coop_game.finish_travel():
            coop_game.end_session("ONLINE AREA COULD NOT BE SAVED. SESSION ENDED.")
            return
    if is_instance_valid(travel_view): travel_view.queue_free()
    message_panel.hide()
    generation_panel.hide()
    generating = false

func _invalidate_travel_maps() -> void:
    map_art_cache = null
    map_art_cache_key = ""
    m257_minimap_raster_key.clear()
    m257_minimap_raster_until = 0
    m3924_minimap_source_cache.clear()
    m3924_minimap_cache_world_id = 0
    m3924_minimap_cache_until = 0
    m3924_minimap_texture_images.clear()
    m3924_minimap_tile_previews.clear()
    m257_minimap_recipes.clear()
    _clear_map_canvas()
    _refresh_m3924_minimap(world.get_map_bounds(), world.player.position)

func _planting_bag_item_allowed(item: String) -> bool:
    if planting_bag_target == null or item == "MANURE": return false
    if not preload("res://scripts/source_plant_farming.gd").plantable(item): return false
    return world.plants().valid(world.exact_world.tile_at(planting_bag_target), item)

func _open_planting_bag(cell: Vector2i) -> void:
    if not world.is_empty_planting_hole(cell): return
    _open_game_menu()
    if not game_menu_open: return
    planting_bag_target = cell
    _show_item_menu()
    for pocket in range(ItemData.POCKET_COUNT):
        var found := false
        for item in ItemData.items_for_pocket(pocket):
            if int(inventory.get(item,0)) > 0 and _planting_bag_item_allowed(item):
                found = true
                break
        if found:
            battle_item_pocket_index = pocket
            _refresh_battle_item_pocket_menu()
            return
    item_pocket_description.text = "No seeds or apricorns in your bag can grow here."

func _sync_pokedex_owned() -> void:
    pokedex_progress.seed_owned(caught_pokemon)
    pokedex_progress.seed_owned(pokemon_storage)
    pokedex_progress.seed_owned(world.deployed_pokemon)
    for cached_world in adjacent_worlds.values():
        if cached_world is Dictionary:
            var crafting: Dictionary = cached_world.get("state", {})
            pokedex_progress.seed_owned(crafting.get("deployed_pokemon", []))

func _warm_map_cache() -> void:
    if not is_instance_valid(waypoint_ui):
        waypoint_ui = preload("res://scripts/map_waypoints.gd").new()
        add_child(waypoint_ui)
        waypoint_ui.configure(self)
    var bounds: Rect2i = world.get_map_bounds()
    if bounds.size.x <= 0 or bounds.size.y <= 0: return
    if map_art_cache_key == preload("res://scripts/source_map_raster.gd").cache_key(self, bounds): return
    map_cache_warming = true
    var texture: Texture2D = await preload("res://scripts/source_map_raster.gd").build(self, bounds, -1)
    map_cache_warming = false
    if texture != null and is_instance_valid(map_view_node) and game_menu_map_screen.visible and map_view_node.size == Vector2(bounds.size * SOURCE_MAP_TILE_PIXELS):
        map_view_node.texture = texture


var swipe_rows: Array[Control] = []
var swipe_selection := 0
var swipe_stick_held := false
var swipe_cursor: TextureRect

func _prepare_swipe_cursor() -> void:
    if is_instance_valid(swipe_cursor): return
    var contents := touch_config.find_child("VBox",true,false)
    for child in contents.get_children():
        if child is BaseButton or child is Slider:
            swipe_rows.append(child)
            var index := swipe_rows.size()-1
            child.mouse_entered.connect(func(): _select_swipe_row(index))
    swipe_cursor = TextureRect.new()
    swipe_cursor.texture = source_command_cursor.texture
    swipe_cursor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    swipe_cursor.size = Vector2(5,7)
    swipe_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    swipe_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    touch_config.add_child(swipe_cursor)
    touch_config_scroll.get_v_scroll_bar().value_changed.connect(func(_value): _position_swipe_cursor())
    _select_swipe_row(0)

func _select_swipe_row(index: int) -> void:
    swipe_selection = wrapi(index,0,swipe_rows.size())
    touch_config_scroll.ensure_control_visible(swipe_rows[swipe_selection])
    _position_swipe_cursor.call_deferred()

func _position_swipe_cursor() -> void:
    if not is_instance_valid(swipe_cursor): return
    var row := swipe_rows[swipe_selection]
    if row == touch_opacity_slider:row=touch_opacity_label
    elif row == touch_size_slider:row=touch_size_label
    swipe_cursor.global_position.x = roundf(row.global_position.x+2)
    _align_control_tick(swipe_cursor,row)
    swipe_cursor.visible = touch_config_scroll.get_global_rect().encloses(swipe_cursor.get_global_rect())

func _handle_swipe_menu(event: InputEvent) -> void:
    if event.is_echo(): return
    if event.is_action_pressed("cancel") or event.is_action_pressed("start"):
        _close_touch_config();return
    var direction := 0
    var change := 0
    if event.is_action_pressed("move_down"): direction=1
    elif event.is_action_pressed("move_up"): direction=-1
    elif event.is_action_pressed("move_right"): change=1
    elif event.is_action_pressed("move_left"): change=-1
    if direction!=0: _select_swipe_row(swipe_selection+direction);return
    var row := swipe_rows[swipe_selection]
    if row is Slider:
        if change!=0: row.value += change*5
    elif event.is_action_pressed("confirm") or change!=0:
        if row is CheckButton:row.button_pressed=not row.button_pressed
        elif event.is_action_pressed("confirm"):row.pressed.emit()

var gen3_switch_busy := false

func _gen3_snapshot() -> Dictionary:
    _sync_pokedex_owned()
    var player = world.player
    var world_name = world_edit.text.strip_edges()
    return {
        "version": 2,
        "world_seed": int(world.get("world_seed")),
        "world_size": int(world.get("map_size_index")),
        "world_name": world_name,
        "player_name": player_model_name.text,
        "player_name_custom": not custom_player_name.is_empty(),
        "player_color": player_color_index,
        "player_model": player_model_index,
        "player_x": player.position.x,
        "player_y": player.position.y,
        "options": GameOptions.values.duplicate(),
        "waypoints": map_waypoints.duplicate(true),
        "pokedex": pokedex_progress.entries.duplicate(),
        "pokedex_shiny": pokedex_progress.shiny_entries.duplicate(),
        "caught_pokemon": caught_pokemon,
        "pokemon_storage": pokemon_storage,
        "preferred_storage_box": preferred_storage_box,
        "inventory": inventory,
        "source_key_items_initialized": true,
        "egg_step_timer": egg_step_timer,
        "friendship_step_timer": friendship_step_timer,
        "next_party_ecology_id": next_party_ecology_id,
        "adjacent_worlds": adjacent_worlds,
        "world_grid_x": current_world_grid.x,
        "world_grid_y": current_world_grid.y,
        "crafting_state": world.get_crafting_save_state()
    }


func switch_gen3_overhaul(next: bool) -> bool:
    if gen3_switch_busy or generating: return false
    var overhaul := load("res://scripts/gen3_overhaul.gd")
    if is_instance_valid(coop_game) and coop_game.active:
        # Applying it in place rebuilds the whole world beside the one already
        # loaded. In an online world that took the game to about 6 GB and
        # Android closed it. Keep the choice and apply it on the next load,
        # where the art is swapped before the world is built.
        # The choice is compared with what is saved, not with what is showing:
        # the art has not changed yet, so comparing with that made a second
        # press do nothing and the option could not be turned back off.
        if GameOptions.enabled("gen3_overhaul") == next: return true
        return GameOptions.change("gen3_overhaul",next) == OK
    if overhaul.enabled == next: return true
    var previous: bool = overhaul.enabled
    if GameOptions.change("gen3_overhaul",next) != OK: return false
    gen3_switch_busy = true
    var previous_process_mode := world.process_mode
    world.process_mode = Node.PROCESS_MODE_DISABLED
    var snapshot: Dictionary = _gen3_snapshot().duplicate(true)
    var field_name := String(world.active_field_move)
    var field_record: Dictionary = world.active_field_pokemon.duplicate(true)
    var leader_position: Vector2 = world.player.position
    var trainer_position: Vector2 = world.work_trainer_position
    var trail: Array = world.work_trail.duplicate()
    var facing: Vector2 = world.player.facing
    var dig_state := {}
    for key in ["dig_step_active","dig_step_target","dig_step_direction","dig_action_pending"]: dig_state[key] = world.get(key)
    options_menu.hide()
    generating = true
    generation_panel.show()
    generation_status.text = "APPLYING GEN3 OPTION...\nPLEASE WAIT..."
    await get_tree().process_frame
    var okay: bool = await overhaul.apply(next,get_tree())
    var rebuilt := false
    if okay:
        player_appearance_texture_cache.clear()
        battle_animation_cache.clear()
        battle_sprite_alpha_cache.clear()
        battle_sprite_frame_counts.clear()
        m3924_minimap_texture_images.clear()
        m3924_minimap_source_cache.clear()
        built_map_art_cache.clear()
        map_art_cache_key = ""
        map_art_cache_context = ""
        map_art_cache = null
        rebuilt = true
        await world.generate_world(int(snapshot.world_seed),int(snapshot.world_size),true)
        okay = world.generation_error.is_empty()
    if not okay:
        GameOptions.change("gen3_overhaul",previous)
        snapshot.options.gen3_overhaul = previous
        if overhaul.enabled != previous:
            await overhaul.apply(previous,get_tree())
            await world.generate_world(int(snapshot.world_seed),int(snapshot.world_size),true)
    if rebuilt and world.generation_error.is_empty():
        world.set_meta("gen3_art_refresh",true)
        await _restore_game_save(snapshot)
        world.remove_meta("gen3_art_refresh")
        if not field_name.is_empty() and not field_record.is_empty():
            world.player.facing = facing
            if field_name in ["CUT","BUILD","DIG","HEADBUTT","SMASH"]: world.player.position=trainer_position
            if world.set_active_field_move(field_record,field_name):
                world.player.position=leader_position
                if field_name in ["CUT","BUILD","DIG","HEADBUTT","SMASH"]:
                    world.work_trail.assign(trail)
                    world.work_trainer_position=trainer_position
                world._place_field_helper_live()
                if field_name == "DIG":
                    for key in dig_state: world.set(key,dig_state[key])
        await _warm_map_cache()
    world.process_mode = previous_process_mode
    world.set_gameplay_enabled(false)
    if is_instance_valid(world.environment_system):
        for music_player in world.environment_system.music_players:
            if music_player.playing:
                music_player.play()
    generating = false
    gen3_switch_busy = false
    generation_panel.hide()
    options_menu.show()
    options_menu.refresh()
    _apply_game_options()
    if not okay: _show_message("GEN3 OVERHAUL could not be applied. The previous option was restored.")
    return okay
