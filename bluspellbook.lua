addon.name = 'bluspellbook';
addon.author = 'Tavarian';
addon.version = '0.1.1';
addon.desc = 'Browse HorizonXI Blue Mage spells by level range in an Ashita 4.3 GUI.';

require 'common';

local imgui = require 'imgui';
local json = require 'json';
local primitives = nil;
pcall(function () primitives = require 'primitives'; end);
local ffxi = nil;
pcall(function () ffxi = require 'ffxi'; end);

local state = {
    is_open = { true, },
    spells = {},
    locations = {},
    selected_range = 1,
    selected_spell_id = nil,
    active_tab = 1,
    spell_search = { '', },
    ui_scale = { 0.75, },
    view_mode = { 2, }, -- Spell list choice: Required, Recommended, or All.
    trait_level_filter = { 0, }, -- Trait list choice: All or Current Level.
    auto_hide_combat = { false, },
    auto_hide_main_menu = { false, },
    show_on_load = { true, },
    show_readme_window = { true, },
    readme_do_not_show_again = { false, },
    readme_dismissed = false,
    readme_lines = {},
    settings_message = '',
    learned_refresh_at = nil,
    learned_refresh_spell_id = nil,
    load_refresh_at = nil,
    known_refresh_at = nil,
    enmity_scan_at = 0,
    learn_message = '',
    learn_message_until = 0,
    learn_message_enabled = { true, },
    learn_message_test = false,
    learn_message_scale = { 1.25, },
    learn_message_position = { 20, 120, },
    mob_spell_trackers = {},
    mob_spell_tracker_order = {},
    mob_spell_message_enabled = { true, },
    detect_known_spells = { false, },
    show_mob_ids = { true, },
    mob_list_background_opacity = { 0.50, },
    mob_spell_message_test = false,
    mob_spell_message_scale = { 1.25, },
    mob_spell_message_position = { 20, 170, },
    mob_move_shift_active = false,
    pending_mob_move_actor_id = nil,
    pending_mob_move_until = 0,
};

local settings_path = addon.path .. '/settings.json';
local learned_font = nil;
local used_font = nil;
local readme_banner = nil;

local function create_readme_banner()
    if (primitives == nil or readme_banner ~= nil) then
        return;
    end

    local ok, banner = pcall(function ()
        local object = primitives.new({
            texture_offset_x = 0.0,
            texture_offset_y = 0.0,
            border_visible = false,
            visible = false,
            position_x = 0,
            position_y = 0,
            can_focus = false,
            locked = true,
            lockedz = false,
            scale_x = 1.0,
            scale_y = 1.0,
            width = 1024.0,
            height = 341.0,
            color = 0xFFFFFFFF,
        });
        object.texture = addon.path .. '/assets/bluspellbook-graffiti-banner.png';
        return object;
    end);
    if (ok) then
        readme_banner = banner;
    end
end

local function hide_readme_banner()
    if (readme_banner ~= nil) then
        readme_banner.visible = false;
    end
end

local function load_settings()
    local file = io.open(settings_path, 'rb');
    if (file == nil) then
        return;
    end

    local contents = file:read('*all');
    file:close();

    local ok, saved = pcall(function ()
        return json.decode(contents);
    end);
    if (not ok or type(saved) ~= 'table') then
        return;
    end

    if (type(saved.ui_scale) == 'number') then
        state.ui_scale[1] = math.max(0.50, math.min(1.75, saved.ui_scale));
    end
    if (type(saved.auto_hide_combat) == 'boolean') then
        state.auto_hide_combat[1] = saved.auto_hide_combat;
    end
    if (type(saved.auto_hide_main_menu) == 'boolean') then
        state.auto_hide_main_menu[1] = saved.auto_hide_main_menu;
    end
    if (type(saved.show_on_load) == 'boolean') then
        state.show_on_load[1] = saved.show_on_load;
    end
    if (type(saved.readme_dismissed) == 'boolean') then
        state.readme_dismissed = saved.readme_dismissed;
        state.show_readme_window[1] = not saved.readme_dismissed;
    end
    if (type(saved.learn_message_x) == 'number' and type(saved.learn_message_y) == 'number') then
        state.learn_message_position = { saved.learn_message_x, saved.learn_message_y, };
    end
    if (type(saved.learn_message_scale) == 'number') then
        state.learn_message_scale[1] = math.max(0.75, math.min(2.50, saved.learn_message_scale));
    end
    if (type(saved.learn_message_enabled) == 'boolean') then
        state.learn_message_enabled[1] = saved.learn_message_enabled;
    end
    if (type(saved.mob_spell_message_enabled) == 'boolean') then
        state.mob_spell_message_enabled[1] = saved.mob_spell_message_enabled;
    end
    if (type(saved.detect_known_spells) == 'boolean') then
        state.detect_known_spells[1] = saved.detect_known_spells;
    end
    if (type(saved.show_mob_ids) == 'boolean') then
        state.show_mob_ids[1] = saved.show_mob_ids;
    end
    if (type(saved.mob_list_background_opacity) == 'number') then
        state.mob_list_background_opacity[1] = math.max(0.0,
            math.min(1.0, saved.mob_list_background_opacity));
    end
    if (type(saved.mob_spell_message_scale) == 'number') then
        state.mob_spell_message_scale[1] = math.max(0.75, math.min(2.50, saved.mob_spell_message_scale));
    end
    if (type(saved.mob_spell_message_x) == 'number' and type(saved.mob_spell_message_y) == 'number') then
        state.mob_spell_message_position = {
            saved.mob_spell_message_x,
            saved.mob_spell_message_y,
        };
    end
end


local function save_settings()
    local saved = {
        ui_scale = state.ui_scale[1],
        auto_hide_combat = state.auto_hide_combat[1],
        auto_hide_main_menu = state.auto_hide_main_menu[1],
        show_on_load = state.show_on_load[1],
        readme_dismissed = state.readme_dismissed,
        learn_message_x = state.learn_message_position[1],
        learn_message_y = state.learn_message_position[2],
        learn_message_scale = state.learn_message_scale[1],
        learn_message_enabled = state.learn_message_enabled[1],
        mob_spell_message_enabled = state.mob_spell_message_enabled[1],
        detect_known_spells = state.detect_known_spells[1],
        show_mob_ids = state.show_mob_ids[1],
        mob_list_background_opacity = state.mob_list_background_opacity[1],
        mob_spell_message_scale = state.mob_spell_message_scale[1],
        mob_spell_message_x = state.mob_spell_message_position[1],
        mob_spell_message_y = state.mob_spell_message_position[2],
    };

    local ok, contents = pcall(function ()
        return json.encode(saved);
    end);
    if (not ok or contents == nil) then
        state.settings_message = 'Unable to encode settings.';
        return;
    end

    local file = io.open(settings_path, 'wb');
    if (file == nil) then
        state.settings_message = 'Unable to open the settings file.';
        return;
    end

    file:write(contents);
    file:close();
    state.settings_message = 'Settings saved.';
end

local function reset_settings_to_defaults()
    state.ui_scale[1] = 0.75;
    state.view_mode[1] = 2;
    state.trait_level_filter[1] = 0;
    state.auto_hide_combat[1] = false;
    state.auto_hide_main_menu[1] = false;
    state.show_on_load[1] = true;
    state.readme_dismissed = false;
    state.readme_do_not_show_again[1] = false;
    state.show_readme_window[1] = true;
    state.learn_message_enabled[1] = true;
    state.learn_message_scale[1] = 1.25;
    state.learn_message_position = { 20, 120, };
    state.mob_spell_message_enabled[1] = true;
    state.detect_known_spells[1] = false;
    state.show_mob_ids[1] = true;
    state.mob_list_background_opacity[1] = 0.50;
    state.mob_spell_message_scale[1] = 1.25;
    state.mob_spell_message_position = { 20, 170, };
    state.learn_message_test = false;
    state.mob_spell_message_test = false;
    save_settings();
    state.settings_message = 'All settings reset to defaults.';
end


local function load_readme_contents()
    local file = io.open(addon.path .. '/README.md', 'rb');
    if (file == nil) then
        state.readme_lines = { 'README.md could not be opened.', };
        return;
    end
    local contents = file:read('*all') or '';
    file:close();
    state.readme_lines = {};
    for line in (contents .. '\n'):gmatch('(.-)\r?\n') do
        table.insert(state.readme_lines, line);
    end
end

-- Try another safe method if this game address cannot be found.
local game_menu_pointer = ashita.memory.find(
    'FFXiMain.dll', 0, '8B480C85C974??8B510885D274??3B05', 16, 0
);

local bsb_hidden_menu_types = {
    -- Do not hide the addon while the player is typing in chat.
    equip = true, inventor = true, mnstorag = true,
    iuse = true, map0 = true, maplist = true, mapframe = true,
    scanlist = true, cnqframe = true, conf2win = true, cfilter = true,
    textcol1 = true, confyn = true, conf5m = true, conf5win = true,
    conf5w1 = true, conf5w2 = true, conf11m = true, conf11l = true,
    conf11s = true, conf3win = true, conf6win = true, conf12wi = true,
    conf13wi = true, fxfilter = true, conf7 = true, conf4 = true,
    link1 = true, link2 = true, link3 = true, link4 = true,
    link5 = true, link6 = true, link7 = true, link8 = true,
    link9 = true, link10 = true, link11 = true, link12 = true,
    link13 = true,
    fulllog = true,
    scresult = true, evitem = true, statcom2 = true,
    itmsortw = true, sortyn = true, itemctrl = true,
    mcr1edlo = true, mcr2edlo = true, mcrbedit = true, mcresed = true,
    bank = true, quest00 = true, quest01 = true, miss00 = true,
    meritcat = true, merit1 = true, merit2 = true, merit3 = true,
    merityn = true, shop = true, bluequip = true, mapv2 = true,
    mapv3 = true, inspect = true,
};

local main_menu_patterns = {
    'menuwind', 'socialme', 'configwi', 'mogcont', 'missionm',
    'auc[%d]', 'itmstora', 'itmsort', 'sortyn', 'region',
    'merit[%d]', 'mnstorag', 'prty[%d]', 'alarm', 'scoption',
    'mgc', 'cmb', 'abi$',
};

local function get_game_menu_name()
    local menu_base = game_menu_pointer or 0;
    if (menu_base == 0) then
        game_menu_pointer = ashita.memory.find(
            'FFXiMain.dll', 0, '8B480C85C974??8B510885D274??3B05', 16, 0
        );
        menu_base = game_menu_pointer or 0;
    end
    if (menu_base == 0) then
        local pointer_ok, pointer_value = pcall(function ()
            return AshitaCore:GetPointerManager():Get('menu');
        end);
        if (pointer_ok and pointer_value ~= nil) then
            menu_base = pointer_value;
        end
    end

    if (menu_base == 0) then
        return '';
    end

    local read_ok, menu_name = pcall(function ()
        local menu_pointer = ashita.memory.read_uint32(menu_base);
        if (menu_pointer == nil or menu_pointer == 0) then return ''; end

        local menu_value = ashita.memory.read_uint32(menu_pointer);
        if (menu_value == nil or menu_value == 0) then return ''; end

        local menu_header = ashita.memory.read_uint32(menu_value + 4);
        if (menu_header == nil or menu_header == 0) then return ''; end

        return ashita.memory.read_string(menu_header + 0x46, 16) or '';
    end);
    if (not read_ok) then
        return '';
    end

    menu_name = menu_name:gsub('\x00', '');
    if (#menu_name >= 9) then
        menu_name = menu_name:sub(9);
    end
    menu_name = menu_name:gsub(' ', '');
    return menu_name:gsub('^%s+', ''):gsub('%s+$', '');
end


local function is_main_menu_open()
    local menu_name = get_game_menu_name();
    for _, pattern in ipairs(main_menu_patterns) do
        if (menu_name:match(pattern)) then
            return true;
        end
    end
    return false;
end


local function is_map_menu_open()
    local menu_name = get_game_menu_name():lower();
    if (menu_name ~= '' and
            (menu_name:find('map', 1, true) ~= nil or
             menu_name:find('region', 1, true) ~= nil or
             menu_name:find('widescan', 1, true) ~= nil or
             menu_name:find('wide', 1, true) ~= nil)) then
        return true;
    end

    if (ffxi ~= nil) then
        local ok, map_open = pcall(function () return ffxi.IsMapOpen(); end);
        if (ok and map_open) then return true; end
    end
    return false;
end


local function is_equipment_menu_open()
    local menu_name = get_game_menu_name():lower();
    if (menu_name == '') then
        return false;
    end

    return menu_name:find('equip', 1, true) ~= nil or
        menu_name:find('eqp', 1, true) ~= nil;
end


local function is_items_menu_open()
    local menu_name = get_game_menu_name():lower();
    if (menu_name == '') then
        return false;
    end

    return menu_name:find('item', 1, true) ~= nil or
        menu_name:find('itm', 1, true) ~= nil;
end


local function is_currencies_menu_open()
    local menu_name = get_game_menu_name():lower();
    if (menu_name == '') then
        return false;
    end

    return menu_name:find('curr', 1, true) ~= nil or
        menu_name:find('pointlist', 1, true) ~= nil or
        menu_name:find('points', 1, true) ~= nil;
end


local function is_config_menu_open()
    local menu_name = get_game_menu_name():lower();
    if (menu_name == '') then
        return false;
    end

    local config_patterns = {
        'config', 'scoption', 'optionwi', 'keyassign', 'keybind',
        'gamepad', 'controller', 'keyboard', 'mousecfg', 'chatcfg',
        'windowcfg', 'fontcfg', 'effectcfg', 'miscfg', 'filtercfg',
    };
    for _, pattern in ipairs(config_patterns) do
        if (menu_name:find(pattern, 1, true) ~= nil) then
            return true;
        end
    end
    return false;
end


local function is_list_sort_options_open()
    local menu_name = get_game_menu_name():lower();
    if (menu_name == '') then
        return false;
    end

    local sort_patterns = {
        'sortyn', 'itmsort', 'mgcsort', 'abisort', 'autosort',
        'manualsort', 'sortmenu', 'sortwi',
    };
    for _, pattern in ipairs(sort_patterns) do
        if (menu_name:find(pattern, 1, true) ~= nil) then
            return true;
        end
    end
    return false;
end


local function is_linkshell_menu_open()
    local menu_name = get_game_menu_name():lower();
    if (menu_name == '' or menu_name == 'inline' or
            menu_name == 'menuwind' or menu_name == 'menu' or
            menu_name == 'command') then
        return false;
    end

    return menu_name:match('^link%d+$') ~= nil or
        menu_name:find('linkshell', 1, true) ~= nil;
end


local system_list_menu_latched = false;

local function is_neutral_menu_name(menu_name)
    -- Stop hiding after the menu has closed.
    return menu_name == 'inline' or menu_name == 'menuwind' or
        menu_name == 'menu' or menu_name == 'command';
end

local function is_system_list_menu_open()
    local menu_name = get_game_menu_name():lower();
    if (menu_name == '' or is_neutral_menu_name(menu_name)) then
        system_list_menu_latched = false;
        return false;
    end

    if (system_list_menu_latched) then
        return true;
    end

    local system_list_patterns = {
        'mission', 'quest', 'keyitem', 'keyitm',
        'viewhouse', 'moghouse', 'mogmenu', 'mogcont',
        'furnish', 'layout', 'storage',
        'bazaar', 'bazar', 'macro',
    };
    for _, pattern in ipairs(system_list_patterns) do
        if (menu_name:find(pattern, 1, true) ~= nil) then
            system_list_menu_latched = true;
            return true;
        end
    end
    return false;
end


local player_search_menu_latched = false;
local player_search_command_armed_until = 0;
local player_search_menu_seen = false;
local player_search_transition_hold_until = 0;

local function is_player_search_menu_open()
    local menu_name = get_game_menu_name():lower();
    if (menu_name == '' or is_neutral_menu_name(menu_name)) then
        -- Give the player-search window time to open.
        if (menu_name == '' and player_search_menu_latched and
                not player_search_menu_seen and
                os.clock() < player_search_command_armed_until) then
            return true;
        end
        -- Keep hiding while player-search pages are changing.
        if (menu_name == '' and player_search_menu_latched and
                player_search_menu_seen and
                os.clock() < player_search_transition_hold_until) then
            return true;
        end
        player_search_menu_latched = false;
        player_search_command_armed_until = 0;
        player_search_menu_seen = false;
        player_search_transition_hold_until = 0;
        return false;
    end

    if (player_search_menu_latched) then
        player_search_menu_seen = true;
        player_search_transition_hold_until = os.clock() + 1.25;
        return true;
    end

    local search_patterns = {
        'search', 'srch', 'shresult', 'searchres', 'playerfind',
    };
    for _, pattern in ipairs(search_patterns) do
        if (menu_name:find(pattern, 1, true) ~= nil) then
            player_search_menu_latched = true;
            player_search_menu_seen = true;
            player_search_transition_hold_until = os.clock() + 1.25;
            return true;
        end
    end
    return false;
end

local function is_addon_hide_menu_open()
    local menu_name = get_game_menu_name():lower();
    if (bsb_hidden_menu_types[menu_name]) then
        return true;
    end
    return is_map_menu_open() or is_equipment_menu_open() or
        is_items_menu_open() or is_currencies_menu_open() or
        is_config_menu_open() or is_list_sort_options_open() or
        is_linkshell_menu_open() or is_system_list_menu_open() or
        is_player_search_menu_open();
end

local required_spells = {
    ['Pollen'] = true, ['Cocoon'] = true, ['Head Butt'] = true,
    ['Healing Breeze'] = true, ['Sheep Song'] = true, ['Bludgeon'] = true,
    ['Wild Carrot'] = true, ['Blank Gaze'] = true, ['Jet Stream'] = true,
    ['Refueling'] = true, ['Frightful Roar'] = true, ['Filamented Hold'] = true,
    ['Magic Fruit'] = true, ['Frenetic Rip'] = true, ['Frypan'] = true,
    ['Voracious Trunk'] = true, ['Diamondhide'] = true,
    ['Hysteric Barrage'] = true, ['Cannonball'] = true,
    ['Disseverment'] = true, ['Saline Coat'] = true,
    ['Temporal Shift'] = true, ['Actinic Burst'] = true,
    ['Magic Hammer'] = true, ['Plasma Charge'] = true, ['Exuviation'] = true,
};

local recommended_spells = {
    ['Wild Oats'] = true, ['Sprout Smack'] = true, ['Battle Dance'] = true,
    ['Soporific'] = true, ['Grand Slam'] = true, ['Chaotic Eye'] = true,
    ['MP Drainkiss'] = true, ['Jettatura'] = true, ['Cold Wave'] = true,
    ['Light of Penance'] = true, ['Death Scissors'] = true,
    ['Feather Tickle'] = true, ['Yawn'] = true, ['Zephyr Mantle'] = true,
    ['Warm-Up'] = true, ['Reactor Cool'] = true,
};

local job_traits = {
    { 'Beast Killer', 4, 'Wild Oats, Sprout Smack, 1000 Needles' },
    { 'Auto Regen', 16, 'Sheep Song, Healing Breeze' },
    { 'Lizard Killer', 20, 'Foot Kick, Claw Cyclone, Ram Charge' },
    { 'Clear Mind', 24, 'Poison Breath, Soporific, Venom Shell, Awful Eye, Filamented Hold, Maelstrom, Feather Tickle, Sandspray, Warm-Up, Lowing, Mind Blast' },
    { 'Magic Accuracy', 28, 'Bomb Toss' },
    { 'Resist Sleep', 30, 'Pollen, Wild Carrot, Magic Fruit, Yawn, Exuviation' },
    { 'Magic Attack Bonus', 32, 'Cursed Sphere, Sound Blast, Eyes On Me, Memento Mori, Heat Breath, Magic Hammer, Reactor Cool, Blank Gaze' },
    { 'Undead Killer', 34, 'Bludgeon, Smite of Rage' },
    { 'Attack Bonus', 38, 'Battle Dance, Uppercut, Death Scissors, Spinal Cleave, Temporal Shift' },
    { 'Rapid Shot', 38, 'Feather Storm, Jet Stream, Hydro Shot' },
    { 'Max MP Boost', 40, 'Metallic Body, Mysterious Light, Hecatomb Wave' },
    { 'Defense Bonus', 40, 'Grand Slam, Terror Touch, Saline Coat, Vertical Cleave, Quad. Continuum' },
    { 'Plantoid Killer', 44, 'Power Attack, Mandibular Bite' },
    { 'Magic Defense Bonus', 50, 'Magnetite Cloud, Ice Break' },
    { 'Auto Refresh', 50, 'Cold Wave (1), Frightful Roar (2), Self-Destruct (2), Light of Penance (2), Voracious Trunk (3), Actinic Burst (4), Plasma Charge (4)' },
    { 'Max HP Boost', 62, 'Flying Hip Press, Body Slam, Frypan, Empty Thrash' },
    { 'Accuracy Bonus', 63, 'Dimensional Death, Frenetic Rip, Disseverment, Vanity Dive' },
    { 'Conserve MP', 65, 'Chaotic Eye, Zephyr Mantle, Frost Breath, Firespit, Metallic Body, Blood Drain, Digest' },
    { 'Evasion Bonus', 69, 'Screwdriver, Hysteric Barrage, Occultation' },
    { 'Resist Gravity', 69, 'Feather Barrier' },
    { 'Store TP', 69, 'Sickle Slash, Tail Slap' },
    { 'Counter', 70, 'Enervation' },
    { 'Fast Cast', 72, 'Bad Breath, Auroral Drape' },
};

local ranges = {
    { 1, 10 },
    { 11, 20 },
    { 21, 30 },
    { 31, 40 },
    { 41, 50 },
    { 51, 60 },
    { 61, 70 },
    { 71, 75 },
    { 1, 75, 'ALL' },
};

local element_names = {
    [0] = 'Fire',
    [1] = 'Ice',
    [2] = 'Wind',
    [3] = 'Earth',
    [4] = 'Lightning',
    [5] = 'Water',
    [6] = 'Light',
    [7] = 'Dark',
    [15] = 'None',
};

local horizon_level_overrides = {
    ['Vanity Dive'] = 28,
    ['Vanity Drive'] = 28,
};

local excluded_spells = {
    ['Asuran Claws'] = true,
    ['Battery Charge'] = true,
    ['Corrosive Ooze'] = true,
    ['Everyone. Grudge'] = true,
    ["Everyone's Grudge"] = true,
    ['Goblin Rush'] = true,
    ['Rail Cannon'] = true,
    ['Regurgitation'] = true,
    ['Seedspray'] = true,
    ['Spiral Spin'] = true,
    ['Stinking Gas'] = true,
    ['Sub-zero Smash'] = true,
    ['Triumphant Roar'] = true,
};

local function get_minimum_blue_magic_skill(level)
    local cap;
    if (level <= 50) then
        cap = ((level - 1) * 3) + 6;
    elseif (level <= 60) then
        cap = ((level - 50) * 5) + 153;
    elseif (level <= 70) then
        cap = math.floor(((level - 60) * 4.85) + 203);
    else
        cap = ((level - 70) * 5) + 251;
    end

    return math.max(0, cap - 31);
end

local function get_blue_mage_level()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil) then
        return nil;
    end

    local ok, main_job, main_level, sub_job, sub_level = pcall(function ()
        return player:GetMainJob(), player:GetMainJobLevel(),
            player:GetSubJob(), player:GetSubJobLevel();
    end);
    if (not ok) then
        return nil;
    end

    if (main_job == 16 and type(main_level) == 'number' and main_level > 0) then
        return math.min(main_level, 75);
    end
    if (sub_job == 16 and type(sub_level) == 'number' and sub_level > 0) then
        return math.min(sub_level, 75);
    end
    return nil;
end

local function get_blue_magic_skill()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil) then
        return 0;
    end

    local ok, skill = pcall(function ()
        return player:GetRawStructure().CombatSkills.BlueMagic:GetSkill();
    end);
    if (ok and type(skill) == 'number') then
        return skill;
    end
    return 0;
end

local function select_current_level_range()
    local level = get_blue_mage_level();
    if (level == nil) then
        return;
    end

    for index, range in ipairs(ranges) do
        if (level >= range[1] and level <= range[2]) then
            state.selected_range = index;
            state.selected_spell_id = nil;
            return;
        end
    end
end

local function load_spells()
    local spells = {};
    local resources = AshitaCore:GetResourceManager();
    local player = AshitaCore:GetMemoryManager():GetPlayer();

    for id = 0, 2048 do
        local resource = resources:GetSpellById(id);
        if (resource ~= nil and resource.Skill == 43) then
            local name = resource.Name[1];
            local level = horizon_level_overrides[name] or resource.LevelRequired[17];
            if (level ~= nil and level > 0 and level <= 75 and
                    not excluded_spells[name]) then
                spells[#spells + 1] = {
                    id = id,
                    name = name,
                    level = level,
                    element = resource.Element,
                    known = player ~= nil and player:HasSpell(id) or false,
                };
            end
        end
    end

    table.sort(spells, function (a, b)
        return a.level < b.level or (a.level == b.level and a.name < b.name);
    end);

    state.spells = spells;
end

local function refresh_known_spells()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil) then
        return false;
    end

    local refreshed = false;
    for _, spell in ipairs(state.spells) do
        local ok, known = pcall(function ()
            return player:HasSpell(spell.id);
        end);
        if (ok) then
            -- Keep a newly learned spell marked while the game catches up.
            spell.known = spell.known or known;
            refreshed = true;
        end
    end
    return refreshed;
end

local function load_locations()
    local file = io.open(addon.path .. '/data/spells.json', 'rb');
    if (file == nil) then
        state.locations = {};
        return;
    end

    local contents = file:read('*all');
    file:close();
    state.locations = json.decode(contents) or {};
end

local function get_selected_spell()
    if (state.selected_spell_id == nil) then
        return nil;
    end

    for _, spell in ipairs(state.spells) do
        if (spell.id == state.selected_spell_id) then
            return spell;
        end
    end

    return nil;
end

local function count_range(range, search_text)
    local count = 0;
    local search = (search_text or ''):lower();
    for _, spell in ipairs(state.spells) do
        local visible = range[3] == 'ALL' or state.view_mode[1] == 2 or
            required_spells[spell.name] or
            (state.view_mode[1] == 1 and recommended_spells[spell.name]);
        local matches_search = search == '' or
            spell.name:lower():find(search, 1, true) ~= nil;
        if (visible and matches_search and
                spell.level >= range[1] and spell.level <= range[2]) then
            count = count + 1;
        end
    end
    return count;
end

local function is_range_complete(range)
    local spell_count = 0;
    for _, spell in ipairs(state.spells) do
        if (spell.level >= range[1] and spell.level <= range[2]) then
            spell_count = spell_count + 1;
            if (not spell.known) then
                return false;
            end
        end
    end
    return spell_count > 0;
end

local function range_has_learnable_spell(range, blue_magic_skill)
    if (get_blue_mage_level() == nil) then
        return false;
    end
    for _, spell in ipairs(state.spells) do
        if (not spell.known and spell.level >= range[1] and spell.level <= range[2] and
                blue_magic_skill >= get_minimum_blue_magic_skill(spell.level)) then
            return true;
        end
    end
    return false;
end

local function draw_range_column()
    local scale = state.ui_scale[1];
    local blue_magic_skill = get_blue_magic_skill();
    imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, '1. Level Range');
    -- Ashita 4.3 needs numbers here instead of named settings.
    imgui.BeginChild('##range_list', { 125 * scale, -1 }, 1, 0);
    for index, range in ipairs(ranges) do
        local complete = is_range_complete(range);
        local has_learnable = range_has_learnable_spell(range, blue_magic_skill);
        if (complete) then
            imgui.PushStyleColor(ImGuiCol_Button, { 0.12, 0.55, 0.22, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.18, 0.68, 0.30, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.22, 0.78, 0.36, 1.0 });
        elseif (has_learnable) then
            imgui.PushStyleColor(ImGuiCol_Button, { 0.68, 0.50, 0.06, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.86, 0.66, 0.10, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonActive, { 1.0, 0.78, 0.16, 1.0 });
        else
            imgui.PushStyleColor(ImGuiCol_Button, { 0.55, 0.10, 0.14, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.72, 0.16, 0.21, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.86, 0.22, 0.28, 1.0 });
        end

        local range_label = range[3] or ('%d-%d'):fmt(range[1], range[2]);
        local label = ('%s##range%d'):fmt(range_label, index);
        if (imgui.Button(label, { 105 * scale, 34 * scale })) then
            state.selected_range = index;
            state.selected_spell_id = nil;
        end

        imgui.PopStyleColor(3);

    end
    imgui.EndChild();
end

local function draw_spell_list()
    local scale = state.ui_scale[1];
    local blue_magic_skill = get_blue_magic_skill();
    local blue_mage_level = get_blue_mage_level();
    local range = ranges[state.selected_range];
    local search = state.spell_search[1]:match('^%s*(.-)%s*$');
    local total = count_range(range, search);

    imgui.TextColored(
        { 1.0, 0.72, 0.30, 1.0 },
        ('2. Learning Target  (%d)'):fmt(total)
    );
    imgui.Text('Search:');
    imgui.SameLine();
    imgui.SetNextItemWidth(120 * scale);
    if (imgui.InputText('##spell_search', state.spell_search, 64)) then
        search = state.spell_search[1]:match('^%s*(.-)%s*$');
        if (search ~= '') then
            state.selected_range = #ranges;
            range = ranges[state.selected_range];
            local search_lower = search:lower();
            state.selected_spell_id = nil;
            for _, spell in ipairs(state.spells) do
                if (spell.name:lower():find(search_lower, 1, true) ~= nil) then
                    state.selected_spell_id = spell.id;
                    break;
                end
            end
        end
    end
    if (search ~= '') then
        imgui.SameLine();
        if (imgui.Button('Clear##spell_search', { 48 * scale, 0 })) then
            state.spell_search[1] = '';
            search = '';
        end
    end
    imgui.BeginChild('##spell_list', { 255 * scale, -1 }, 1, 0);

    for _, spell in ipairs(state.spells) do
        local visible = range[3] == 'ALL' or state.view_mode[1] == 2 or
            required_spells[spell.name] or
            (state.view_mode[1] == 1 and recommended_spells[spell.name]);
        local matches_search = search == '' or
            spell.name:lower():find(search:lower(), 1, true) ~= nil;
        if (visible and matches_search and
                spell.level >= range[1] and spell.level <= range[2]) then
            local selected = state.selected_spell_id == spell.id;
            local status_color;
            if (spell.known) then
                status_color = { 0.35, 1.0, 0.45, 1.0 };
            elseif (blue_mage_level ~= nil and
                    blue_magic_skill >= get_minimum_blue_magic_skill(spell.level)) then
                status_color = { 1.0, 0.82, 0.16, 1.0 };
            else
                status_color = { 1.0, 0.28, 0.28, 1.0 };
                if (selected) then
                    imgui.PushStyleColor(ImGuiCol_Header, { 0.42, 0.07, 0.11, 1.0 });
                    imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 0.62, 0.10, 0.16, 1.0 });
                    imgui.PushStyleColor(ImGuiCol_HeaderActive, { 0.78, 0.14, 0.20, 1.0 });
                end
            end
            imgui.PushStyleColor(ImGuiCol_Text, status_color);

            local marker = selected and '> ' or '  ';
            local known_mark = spell.known and '✓' or 'X';
            local label = ('%s[%s] Lv.%02d  %s##spell%d'):fmt(marker, known_mark, spell.level, spell.name, spell.id);
            if (imgui.Selectable(label, selected)) then
                state.selected_spell_id = spell.id;
            end
            imgui.PopStyleColor();
            if (selected and not spell.known and
                    (blue_mage_level == nil or
                    blue_magic_skill < get_minimum_blue_magic_skill(spell.level))) then
                imgui.PopStyleColor(3);
            end
        end
    end

    imgui.EndChild();
end

local function show_value(label, value)
    imgui.TextColored({ 0.78, 0.82, 0.90, 1.0 }, label);
    imgui.SameLine();
    imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, tostring(value));
end

local function draw_location_column()
    imgui.TextColored({ 1.0, 0.72, 0.30, 1.0 }, '3. Learn Locations');
    imgui.BeginChild('##learn_locations', { 0, -1 }, 1, 0);

    local spell = get_selected_spell();
    if (spell == nil) then
        imgui.TextWrapped('Select the spell you are currently trying to learn. Its monster and zone options will appear here.');
        imgui.Spacing();
        imgui.Spacing();
        imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 0.82, 0.16, 1.0 });
        imgui.TextWrapped('Not all locations could be verified, and some may be missing. To report a location or an issue with the addon, contact Tavarian on the HorizonXI Discord.');
        imgui.PopStyleColor();
        imgui.EndChild();
        return;
    end

    local resource = AshitaCore:GetResourceManager():GetSpellById(spell.id);
    if (resource == nil) then
        imgui.TextColored({ 1.0, 0.25, 0.25, 1.0 }, 'Spell resource data is unavailable.');
        imgui.EndChild();
        return;
    end

    imgui.TextColored({ 0.45, 0.82, 1.0, 1.0 }, ('Currently Learning: %s'):fmt(spell.name));
    imgui.PushTextWrapPos(0);
    imgui.TextWrapped(resource.Description[1] or 'No spell description is available.');
    imgui.PopTextWrapPos();
    imgui.Separator();
    show_value('Level:', spell.level);
    show_value('Element:', element_names[spell.element] or tostring(spell.element));
    show_value('Minimum Blue Magic Skill:', get_minimum_blue_magic_skill(spell.level));
    if (imgui.Button('Open HorizonXI Wiki Page')) then
        local page_name = spell.name:gsub(' ', '_');
        ashita.misc.open_url(('https://horizonffxi.wiki/%s'):fmt(page_name));
    end
    imgui.Separator();

    local locations = state.locations[tostring(spell.id)];
    if (locations ~= nil and type(locations.status) == 'string') then
        imgui.TextColored({ 1.0, 0.78, 0.28, 1.0 }, locations.status);
    elseif (locations == nil or #locations == 0) then
        imgui.TextWrapped('No known location - will update when available');
    else
        local zones = {};
        for _, entry in ipairs(locations) do
            if (zones[entry.zone] == nil) then
                zones[entry.zone] = { min_level = entry.level_min, monsters = {} };
            end
            zones[entry.zone].min_level = math.min(zones[entry.zone].min_level, entry.level_min);
            zones[entry.zone].monsters[#zones[entry.zone].monsters + 1] = entry;
        end

        local zone_names = {};
        for zone_name in pairs(zones) do
            zone_names[#zone_names + 1] = zone_name;
        end
        table.sort(zone_names, function (a, b)
            return zones[a].min_level < zones[b].min_level or
                (zones[a].min_level == zones[b].min_level and a < b);
        end);

        for _, zone_name in ipairs(zone_names) do
            imgui.TextColored({ 1.0, 0.78, 0.28, 1.0 }, zone_name);
            for _, entry in ipairs(zones[zone_name].monsters) do
                local level_text = entry.level_unknown and 'Unknown' or
                    (entry.level_min == entry.level_max and
                    tostring(entry.level_min) or
                    ('%d-%d'):fmt(entry.level_min, entry.level_max));
                local location_note = type(entry.note) == 'string' and
                    entry.note ~= '' and ('  %s'):fmt(entry.note) or '';
                imgui.BulletText(('%s  (Lv.%s)%s'):fmt(
                    entry.monster, level_text, location_note
                ));
            end
            imgui.Spacing();
        end
    end

    imgui.EndChild();
end

local function draw_job_traits()
    local scale = state.ui_scale[1];
    local player_level = get_blue_mage_level() or 0;

    local known_spells = {};
    local spell_levels = {};
    for _, spell in ipairs(state.spells) do
        known_spells[spell.name] = spell.known;
        spell_levels[spell.name] = tonumber(spell.level);
    end

    local function get_priority_spells(trait, maximum_level)
        local groups = { {}, {}, {} };
        local spell_limit = trait[1] == 'Auto Refresh' and 3 or 2;
        for value in trait[3]:gmatch('[^,]+') do
            local item = value:match('^%s*(.-)%s*$');
            local name = item:gsub('%s*%(%d+%)%s*$', '');
            local spell_level = spell_levels[name];
            if (spell_level ~= nil and spell_level <= maximum_level) then
                local group = required_spells[name] and 1 or (recommended_spells[name] and 2 or 3);
                groups[group][#groups[group] + 1] = {
                    item = item,
                    name = name,
                    priority = group,
                };
            end
        end

        local selected = {};
        for priority = 1, 3 do
            for _, spell in ipairs(groups[priority]) do
                selected[#selected + 1] = spell;
                if (#selected == spell_limit) then
                    return selected;
                end
            end
        end
        return selected;
    end

    local function has_trait_spell_requirements(trait, maximum_level)
        local known_count = 0;
        local known_points = 0;
        local uses_points = false;
        for value in trait[3]:gmatch('[^,]+') do
            local item = value:match('^%s*(.-)%s*$');
            local points = tonumber(item:match('%((%d+)%)%s*$'));
            local name = item:gsub('%s*%(%d+%)%s*$', '');
            if (points ~= nil) then
                uses_points = true;
            else
                points = 1;
            end
            if (known_spells[name] and spell_levels[name] ~= nil and
                    spell_levels[name] <= maximum_level) then
                known_count = known_count + 1;
                known_points = known_points + points;
            end
        end

        return uses_points and known_points >= 8 or (not uses_points and known_count >= 2);
    end

    imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, 'Blue Mage Job Traits (Level 75)');
    imgui.TextDisabled('Active traits are blue. Learned spells are green. Unavailable traits are red.');
    imgui.SetNextItemWidth(170 * scale);
    imgui.Combo(
        '##trait_level_filter',
        state.trait_level_filter,
        'All\0Current Level\0\0'
    );
    imgui.SameLine();
    imgui.TextDisabled('Show all traits or only those currently available');
    imgui.Separator();
    imgui.BeginChild('##job_trait_list', { 0, -1 }, 1, 0);

    imgui.Columns(3, '##trait_columns', true);
    imgui.SetColumnWidth(0, 190 * scale);
    imgui.SetColumnWidth(1, 130 * scale);
    imgui.TextColored({ 1.0, 0.72, 0.30, 1.0 }, 'Trait');
    imgui.NextColumn();
    imgui.TextColored({ 1.0, 0.72, 0.30, 1.0 }, 'Available Level');
    imgui.NextColumn();
    imgui.TextColored({ 1.0, 0.72, 0.30, 1.0 }, 'Spell Contributors');
    imgui.NextColumn();
    imgui.Separator();

    for _, trait in ipairs(job_traits) do
        local filter_index = state.trait_level_filter[1];
        local visible = filter_index == 0 or trait[2] <= player_level;
        if (visible) then
            local can_acquire = player_level >= trait[2] and
                has_trait_spell_requirements(trait, player_level);
            if (not can_acquire) then
                imgui.TextColored({ 1.0, 0.28, 0.28, 1.0 }, trait[1]);
            else
                imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, trait[1]);
            end
            imgui.NextColumn();
            if (not can_acquire) then
                imgui.TextColored({ 1.0, 0.28, 0.28, 1.0 }, ('Lv.%d'):fmt(trait[2]));
            else
                imgui.Text(('Lv.%d'):fmt(trait[2]));
            end
            imgui.NextColumn();
            imgui.PushTextWrapPos(0);
            local contributor_level = filter_index == 0 and 75 or player_level;
            for _, spell in ipairs(get_priority_spells(trait, contributor_level)) do
                local text = spell.item;
                if (known_spells[spell.name]) then
                    imgui.TextColored({ 0.35, 1.0, 0.45, 1.0 }, text);
                else
                    imgui.Text(text);
                end
            end
            imgui.PopTextWrapPos();
            imgui.NextColumn();
            imgui.Separator();
        end
    end

    imgui.Columns(1);
    imgui.EndChild();
end

local function push_scaled_style(scale)
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 8 * scale, 8 * scale });
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 4 * scale, 3 * scale });
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 8 * scale, 4 * scale });
    imgui.PushStyleVar(ImGuiStyleVar_ItemInnerSpacing, { 4 * scale, 4 * scale });
    imgui.PushStyleVar(ImGuiStyleVar_IndentSpacing, 21 * scale);
    imgui.PushStyleVar(ImGuiStyleVar_ScrollbarSize, 14 * scale);
    imgui.PushStyleVar(ImGuiStyleVar_GrabMinSize, 10 * scale);
    return 7;
end

local function push_title_bar_style()
    imgui.PushStyleColor(ImGuiCol_TitleBg, { 0.012, 0.031, 0.09, 1.0 });
    imgui.PushStyleColor(ImGuiCol_TitleBgActive, { 0.0, 0.42, 1.0, 1.0 });
    imgui.PushStyleColor(ImGuiCol_TitleBgCollapsed, { 0.0, 0.24, 0.78, 1.0 });
end

local function push_control_style()
    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.165, 0.255, 0.405, 0.94 });
    imgui.PushStyleColor(ImGuiCol_ChildBg, { 0.190, 0.245, 0.340, 0.92 });
    imgui.PushStyleColor(ImGuiCol_Border, { 0.12, 0.30, 0.52, 0.72 });
    imgui.PushStyleColor(ImGuiCol_Text, { 0.93, 0.97, 1.0, 1.0 });
    imgui.PushStyleColor(ImGuiCol_TextDisabled, { 0.62, 0.86, 1.0, 1.0 });
    imgui.PushStyleColor(ImGuiCol_FrameBg, { 0.043, 0.071, 0.125, 1.0 });
    imgui.PushStyleColor(ImGuiCol_FrameBgHovered, { 0.055, 0.24, 0.48, 1.0 });
    imgui.PushStyleColor(ImGuiCol_FrameBgActive, { 0.0, 0.48, 0.84, 1.0 });
    imgui.PushStyleColor(ImGuiCol_Button, { 0.063, 0.094, 0.153, 1.0 });
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.055, 0.30, 0.60, 1.0 });
    imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.0, 0.52, 0.82, 1.0 });
    imgui.PushStyleColor(ImGuiCol_Header, { 0.078, 0.13, 0.24, 1.0 });
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 0.055, 0.30, 0.60, 1.0 });
    imgui.PushStyleColor(ImGuiCol_HeaderActive, { 0.0, 0.48, 0.78, 1.0 });
    imgui.PushStyleColor(ImGuiCol_CheckMark, { 0.30, 0.92, 1.0, 1.0 });
    imgui.PushStyleColor(ImGuiCol_SliderGrab, { 0.0, 0.66, 0.92, 1.0 });
    imgui.PushStyleColor(ImGuiCol_SliderGrabActive, { 0.30, 0.92, 1.0, 1.0 });
    imgui.PushStyleColor(ImGuiCol_PopupBg, { 0.190, 0.245, 0.340, 0.97 });
    return 18;
end

local function push_gold_button_style()
    imgui.PushStyleColor(ImGuiCol_Button, { 0.57, 0.40, 0.05, 1.0 });
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.91, 0.71, 0.21, 1.0 });
    imgui.PushStyleColor(ImGuiCol_ButtonActive, { 1.0, 0.80, 0.24, 1.0 });
end

local function push_red_button_style()
    imgui.PushStyleColor(ImGuiCol_Button, { 0.48, 0.09, 0.25, 1.0 });
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.84, 0.18, 0.40, 1.0 });
    imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.94, 0.27, 0.49, 1.0 });
end

local function push_scaled_font(scale)
    -- Resize only this addon's text when Ashita supports it.
    local current_font = imgui.GetFont();
    local current_size = imgui.GetFontSize();
    if (current_font ~= nil and type(current_size) == 'number') then
        local wanted_size = math.max(6, current_size * scale);
        local pushed = pcall(function ()
            imgui.PushFont(current_font, wanted_size);
        end);
        if (pushed) then
            return { font = current_font, dynamic_size = true };
        end
    end

    -- Otherwise, use the closest font size already loaded by Ashita.
    local io_ok, io = pcall(imgui.GetIO);
    if (io_ok and io ~= nil and current_font ~= nil and type(current_size) == 'number') then
        local atlas_ok, fonts = pcall(function () return io.Fonts.Fonts; end);
        if (atlas_ok and fonts ~= nil) then
            local wanted_size = current_size * scale;
            local best_font = nil;
            local best_distance = math.huge;
            local seen = {};
            -- Handle both ways Ashita may number this list.
            for index = 0, 63 do
                local item_ok, candidate = pcall(function () return fonts[index]; end);
                if (item_ok and candidate ~= nil and not seen[candidate]) then
                    seen[candidate] = true;
                    local size_ok, candidate_size = pcall(function () return candidate.FontSize; end);
                    if (size_ok and type(candidate_size) == 'number') then
                        local distance = math.abs(candidate_size - wanted_size);
                        if (distance < best_distance) then
                            best_font = candidate;
                            best_distance = distance;
                        end
                    end
                end
            end
            for index = 1, 64 do
                local item_ok, candidate = pcall(function () return fonts[index]; end);
                if (item_ok and candidate ~= nil and not seen[candidate]) then
                    seen[candidate] = true;
                    local size_ok, candidate_size = pcall(function () return candidate.FontSize; end);
                    if (size_ok and type(candidate_size) == 'number') then
                        local distance = math.abs(candidate_size - wanted_size);
                        if (distance < best_distance) then
                            best_font = candidate;
                            best_distance = distance;
                        end
                    end
                end
            end
            if (best_font ~= nil) then
                local pushed = pcall(function () imgui.PushFont(best_font); end);
                if (pushed) then
                    return { font = best_font, atlas_font = true };
                end
            end
        end
    end

    -- Make sure the text size really changed because some Ashita versions ignore it.
    local io_ok, io = pcall(imgui.GetIO);
    if (io_ok and io ~= nil) then
        local scale_ok, original_global_scale = pcall(function ()
            return io.FontGlobalScale;
        end);
        if (scale_ok and type(original_global_scale) == 'number') then
            local wanted_global_scale = original_global_scale * scale;
            local changed = pcall(function ()
                io.FontGlobalScale = wanted_global_scale;
            end);
            local verify_ok, applied_global_scale = pcall(function ()
                return io.FontGlobalScale;
            end);
            if (changed and verify_ok and type(applied_global_scale) == 'number' and
                math.abs(applied_global_scale - wanted_global_scale) < 0.001) then
                return {
                    io = io,
                    original_global_scale = original_global_scale,
                };
            end
            pcall(function () io.FontGlobalScale = original_global_scale; end);
        end
    end

    -- Use this last option for older Ashita versions.
    local font = imgui.GetFont();
    if (font == nil) then
        return nil;
    end

    local ok, original_scale = pcall(function ()
        return font.Scale;
    end);
    if (not ok or original_scale == nil) then
        return nil;
    end

    local wanted_scale = original_scale * scale;
    local changed = pcall(function ()
        font.Scale = wanted_scale;
    end);
    local verify_ok, applied_scale = pcall(function ()
        return font.Scale;
    end);
    if (not changed or not verify_ok or type(applied_scale) ~= 'number' or
        math.abs(applied_scale - wanted_scale) >= 0.001) then
        pcall(function () font.Scale = original_scale; end);
        return nil;
    end

    local pushed = pcall(function ()
        imgui.PushFont(font);
    end);
    if (not pushed) then
        pcall(function () font.Scale = original_scale; end);
        return nil;
    end

    return { font = font, original_scale = original_scale };
end


local function pop_scaled_font(font_state)
    if (font_state == nil) then
        return;
    end

    if (font_state.io ~= nil) then
        pcall(function ()
            font_state.io.FontGlobalScale = font_state.original_global_scale;
        end);
        return;
    end

    imgui.PopFont();
    if (font_state.atlas_font or font_state.dynamic_size) then
        return;
    end
    pcall(function ()
        font_state.font.Scale = font_state.original_scale;
    end);
end


local function find_entity_index(server_id)
    local entity = AshitaCore:GetMemoryManager():GetEntity();
    if (entity == nil) then
        return nil;
    end

    for index = 0, 2303 do
        local ok, id = pcall(function ()
            return entity:GetServerId(index);
        end);
        if (ok and id == server_id) then
            return index;
        end
    end
    return nil;
end


local function get_english_resource_name(name_value)
    if (type(name_value) == 'string') then
        return name_value;
    end
    if (name_value == nil) then return nil; end
    local ok, value = pcall(function ()
        return name_value[1] or name_value[0];
    end);
    if (ok and type(value) == 'string') then
        return value;
    end
    return nil;
end


local function find_blue_spell_name(ability_name)
    ability_name = get_english_resource_name(ability_name);
    if (ability_name == nil or ability_name == '') then
        return nil;
    end

    for _, spell in ipairs(state.spells) do
        if (spell.name == ability_name or
                (spell.name == 'Vanity Dive' and ability_name == 'Vanity Drive') or
                (spell.name == 'Vanity Drive' and ability_name == 'Vanity Dive') or
                (spell.name == 'Empty Thrash' and ability_name == 'Empty Trash') or
                (spell.name == 'Empty Trash' and ability_name == 'Empty Thrash') or
                (spell.name == 'Winds of Promy.' and ability_name == 'Winds of Promyvion') or
                (spell.name == 'Quad. Continuum' and ability_name == 'Quadratic Continuum')) then
            return spell.name;
        end
    end

    -- Also find spells listed in the location data but not in the main level list.
    local wanted = ability_name:lower();
    for spell_id, _ in pairs(state.locations) do
        local resource = AshitaCore:GetResourceManager():GetSpellById(tonumber(spell_id));
        if (resource ~= nil and resource.Name ~= nil) then
            local resource_name = get_english_resource_name(resource.Name);
            if (type(resource_name) == 'string' and resource_name:lower() == wanted) then
                return resource_name;
            end
        end
    end
    return nil;
end


local function find_blue_spell_id(spell_name)
    for _, spell in ipairs(state.spells) do
        if (spell.name == spell_name) then
            return spell.id;
        end
    end
    local wanted = type(spell_name) == 'string' and spell_name:lower() or '';
    for spell_id, _ in pairs(state.locations) do
        local numeric_id = tonumber(spell_id);
        local resource = AshitaCore:GetResourceManager():GetSpellById(numeric_id);
        if (resource ~= nil and resource.Name ~= nil) then
            local resource_name = get_english_resource_name(resource.Name);
            if (type(resource_name) == 'string' and resource_name:lower() == wanted) then
                return numeric_id;
            end
        end
    end
    return nil;
end


local function is_blue_spell_known(spell_name)
    for _, spell in ipairs(state.spells) do
        if (spell.name == spell_name) then
            return spell.known == true;
        end
    end
    local spell_id = find_blue_spell_id(spell_name);
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (spell_id ~= nil and player ~= nil) then
        local ok, known = pcall(function () return player:HasSpell(spell_id); end);
        if (ok) then return known == true; end
    end
    return false;
end


local mob_teaches_blue_spell = nil;


local function increment_mob_spell(tracker, spell_name)
    if (tracker == nil or spell_name == nil) then
        return false;
    end
    if (not state.detect_known_spells[1] and is_blue_spell_known(spell_name)) then
        return false;
    end
    if (mob_teaches_blue_spell == nil or
            not mob_teaches_blue_spell(tracker.name, spell_name)) then
        return false;
    end

    -- Do not count the same enemy move twice.
    tracker.last_spell_at = tracker.last_spell_at or {};
    local now = os.clock();
    local last = tracker.last_spell_at[spell_name];
    if (last ~= nil and now - last < 5.0) then
        return false;
    end
    tracker.last_spell_at[spell_name] = now;

    if (tracker.counts[spell_name] == nil) then
        tracker.counts[spell_name] = 0;
        tracker.spell_order[#tracker.spell_order + 1] = spell_name;
    end
    tracker.counts[spell_name] = tracker.counts[spell_name] + 1;
    return true;
end


local function remove_mob_spell_tracker(actor_id)
    state.mob_spell_trackers[actor_id] = nil;
    for index = #state.mob_spell_tracker_order, 1, -1 do
        if (state.mob_spell_tracker_order[index] == actor_id) then
            table.remove(state.mob_spell_tracker_order, index);
            break;
        end
    end
end


local function normalize_mob_name(name)
    if (type(name) ~= 'string') then return ''; end
    return name:lower():gsub('^the%s+', ''):gsub('^%s+', ''):gsub('%s+$', '');
end


mob_teaches_blue_spell = function (mob_name, spell_name)
    local wanted_mob = normalize_mob_name(mob_name);
    if (wanted_mob == '') then return false; end

    local spell_id = find_blue_spell_id(spell_name);
    if (spell_id == nil) then return false; end

    local entries = state.locations[tostring(spell_id)];
    if (type(entries) ~= 'table') then return false; end
    for _, entry in ipairs(entries) do
        if (normalize_mob_name(entry.monster) == wanted_mob) then
            return true;
        end
    end
    return false;
end


local function mob_has_learnable_blue_magic(name)
    local wanted = normalize_mob_name(name);
    if (wanted == '') then return false; end
    for spell_id, entries in pairs(state.locations) do
        if (type(entries) == 'table') then
            for _, entry in ipairs(entries) do
                if (normalize_mob_name(entry.monster) == wanted) then
                    if (state.detect_known_spells[1]) then
                        return true;
                    end
                    local numeric_id = tonumber(spell_id);
                    local found_display_spell = false;
                    for _, spell in ipairs(state.spells) do
                        if (spell.id == numeric_id and not spell.known) then
                            return true;
                        end
                        if (spell.id == numeric_id) then
                            found_display_spell = true;
                        end
                    end
                    if (not found_display_spell) then
                        local player = AshitaCore:GetMemoryManager():GetPlayer();
                        local known = false;
                        if (player ~= nil) then
                            local ok, value = pcall(function ()
                                return player:HasSpell(numeric_id);
                            end);
                            known = ok and value == true;
                        end
                        if (not known) then return true; end
                    end
                end
            end
        end
    end
    return false;
end


local function get_mob_learnable_spell_names(name)
    local wanted = normalize_mob_name(name);
    local names = {};
    local seen = {};
    if (wanted == '') then return names; end

    for spell_id, entries in pairs(state.locations) do
        if (type(entries) == 'table') then
            local teaches = false;
            for _, entry in ipairs(entries) do
                if (normalize_mob_name(entry.monster) == wanted) then
                    teaches = true;
                    break;
                end
            end
            if (teaches) then
                local numeric_id = tonumber(spell_id);
                local resource = AshitaCore:GetResourceManager():GetSpellById(numeric_id);
                local spell_name = resource ~= nil and
                    get_english_resource_name(resource.Name) or nil;
                if (type(spell_name) == 'string' and spell_name ~= '' and
                        not seen[spell_name] and
                        (state.detect_known_spells[1] or
                         not is_blue_spell_known(spell_name))) then
                    seen[spell_name] = true;
                    names[#names + 1] = spell_name;
                end
            end
        end
    end
    table.sort(names);
    return names;
end


local function ensure_mob_spell_tracker(actor_id)
    if (actor_id == nil or actor_id == 0) then
        return nil;
    end
    if (state.mob_spell_trackers[actor_id] ~= nil) then
        return state.mob_spell_trackers[actor_id];
    end

    local entity = AshitaCore:GetMemoryManager():GetEntity();
    local entity_index = find_entity_index(actor_id);
    if (entity == nil or entity_index == nil) then
        return nil;
    end

    -- Never show party or alliance members as enemies.
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party ~= nil) then
        for member = 0, 17 do
            local id_ok, member_id = pcall(function ()
                return party:GetMemberServerId(member);
            end);
            if (id_ok and member_id == actor_id) then
                return nil;
            end
        end
    end

    local ok, name = pcall(function ()
        return entity:GetName(entity_index);
    end);
    -- Game does not always label spawned enemies correctly.
    if (not ok) then
        return nil;
    end
    -- Some real Promyvion enemies fail the normal enemy check.
    if (not mob_has_learnable_blue_magic(name)) then
        return nil;
    end

    local tracker = {
        actor_id = actor_id,
        actor_index = entity_index,
        name = type(name) == 'string' and name ~= '' and name or ('Mob %08X'):fmt(actor_id),
        counts = {},
        spell_order = {},
        last_spell_at = {},
    };
    state.mob_spell_trackers[actor_id] = tracker;
    state.mob_spell_tracker_order[#state.mob_spell_tracker_order + 1] = actor_id;
    return tracker;
end


local function get_party_server_ids()
    local ids = {};
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party == nil) then
        return ids;
    end
    for member = 0, 17 do
        local ok, server_id = pcall(function ()
            return party:GetMemberServerId(member);
        end);
        if (ok and server_id ~= nil and server_id ~= 0) then
            ids[server_id] = true;
        end
    end
    return ids;
end


local function track_party_enmity_action(actor_id, target_id)
    if (actor_id == target_id) then
        return;
    end
    local party_ids = get_party_server_ids();
    if (party_ids[actor_id]) then
        ensure_mob_spell_tracker(target_id);
    elseif (party_ids[target_id]) then
        ensure_mob_spell_tracker(actor_id);
    end
end


local function track_party_battle_targets()
    local memory = AshitaCore:GetMemoryManager();
    local party = memory:GetParty();
    local entity = memory:GetEntity();
    if (party == nil or entity == nil) then
        return;
    end

    local party_entity_indices = {};
    for member = 0, 17 do
        local ok, server_id, member_index, member_status, target_index = pcall(function ()
            local index = party:GetMemberTargetIndex(member);
            return party:GetMemberServerId(member), index,
                entity:GetStatus(index), entity:GetTargetIndex(index);
        end);
        if (ok and server_id ~= nil and server_id ~= 0 and
                type(member_index) == 'number' and member_index > 0) then
            party_entity_indices[member_index] = true;
            if (member_status == 1 and target_index ~= nil and target_index ~= 0) then
                local id_ok, target_id = pcall(function ()
                    return entity:GetServerId(target_index);
                end);
                if (id_ok and target_id ~= nil and target_id ~= 0) then
                    ensure_mob_spell_tracker(target_id);
                end
            end
        end
    end

    if (os.clock() < state.enmity_scan_at) then
        return;
    end
    state.enmity_scan_at = os.clock() + 0.25;
    for entity_index = 0, 2303 do
        if (not party_entity_indices[entity_index]) then
            local ok, status, target_index, server_id = pcall(function ()
                return entity:GetStatus(entity_index), entity:GetTargetIndex(entity_index),
                    entity:GetServerId(entity_index);
            end);
            if (ok and status == 1 and party_entity_indices[target_index] and
                    server_id ~= nil and server_id ~= 0) then
                ensure_mob_spell_tracker(server_id);
            end
        end
    end
end


local function record_mob_blue_spell(actor_id, ability_id)
    local spell_name = nil;
    -- Game can use either of two numbers for the same enemy move.
    local candidates = { ability_id, ability_id + 256 };
    if (ability_id >= 256) then
        candidates[#candidates + 1] = ability_id - 256;
    end
    for _, resource_id in ipairs(candidates) do
        local ability = AshitaCore:GetResourceManager():GetAbilityById(resource_id);
        if (ability ~= nil and ability.Name ~= nil) then
            local ability_name = get_english_resource_name(ability.Name);
            spell_name = find_blue_spell_name(ability_name);
            if (spell_name ~= nil) then
                break;
            end
        end
    end
    if (spell_name == nil) then return false; end

    -- When a move finishes, also add enemies missed by the earlier group check.
    local tracker = state.mob_spell_trackers[actor_id] or ensure_mob_spell_tracker(actor_id);
    if (tracker == nil) then
        return false;
    end
    return increment_mob_spell(tracker, spell_name);
end


local function update_mob_spell_tracker()
    local entity = AshitaCore:GetMemoryManager():GetEntity();
    for index = #state.mob_spell_tracker_order, 1, -1 do
        local actor_id = state.mob_spell_tracker_order[index];
        local tracker = state.mob_spell_trackers[actor_id];
        for spell_index = #tracker.spell_order, 1, -1 do
            local spell_name = tracker.spell_order[spell_index];
            if (not state.detect_known_spells[1] and
                    is_blue_spell_known(spell_name)) then
                table.remove(tracker.spell_order, spell_index);
                tracker.counts[spell_name] = nil;
                tracker.last_spell_at[spell_name] = nil;
            end
        end
        local ok, server_id, entity_status = pcall(function ()
            return entity:GetServerId(tracker.actor_index),
                entity:GetStatus(tracker.actor_index);
        end);
        -- Do not remove an enemy only because Game briefly reports zero health.
        if (not ok or server_id ~= actor_id or
                entity_status == 2 or entity_status == 3 or
                not mob_has_learnable_blue_magic(tracker.name)) then
            remove_mob_spell_tracker(actor_id);
        end
    end
end


local function set_message_font_visible(font, visible)
    if (font == nil) then
        return false;
    end

    -- Work with both older and newer Ashita show-and-hide methods.
    local attempts = {
        function () font:SetVisible(visible); end,
        function () font:SetVisibility(visible); end,
        function () font.Visible = visible; end,
        function () font.Visibility = visible; end,
        function () font.visible = visible; end,
        function () font.visibility = visible; end,
    };
    for _, attempt in ipairs(attempts) do
        if (pcall(attempt)) then
            return true;
        end
    end
    return false;
end


local function create_message_font(alias, position, color)
    local manager = AshitaCore:GetFontManager();
    pcall(function () manager:Delete(alias); end);
    local font = manager:Create(alias);
    if (font == nil) then
        return nil;
    end

    font:SetFontFamily('Arial');
    font:SetFontHeight(16);
    font:SetColor(color);
    font:SetBold(false);
    font:SetAutoResize(true);
    font:SetPadding(0);
    font:SetPositionX(position[1]);
    font:SetPositionY(position[2]);
    font:SetLocked(true);
    -- Older Ashita versions hide this message when its text is empty.
    font:SetText('');
    set_message_font_visible(font, false);
    pcall(function () font:GetBackground():SetColor(0x00000000); end);
    return font;
end


local function create_message_fonts()
    learned_font = create_message_font(
        'bluspellbook_learned_message', state.learn_message_position, 0xFF59FF73
    );
    used_font = create_message_font(
        'bluspellbook_used_message', state.mob_spell_message_position, 0xFFFFD129
    );
end


local function update_used_message_background()
    if (used_font == nil) then return; end
    local opacity = math.max(0.0, math.min(1.0,
        state.mob_list_background_opacity[1]));
    local alpha = math.floor(opacity * 255 + 0.5);
    local background = nil;
    pcall(function () background = used_font:GetBackground(); end);
    if (background == nil) then return; end
    pcall(function () background:SetColor(alpha * 0x1000000); end);
    -- Work with both older and newer Ashita background methods.
    local visible = opacity > 0.0;
    local visible_ok = pcall(function () background:SetVisible(visible); end);
    if (not visible_ok) then
        pcall(function () background:SetVisibility(visible); end);
    end
end


local function read_font_position(font, position)
    if (font == nil) then
        return;
    end
    local ok, x, y = pcall(function ()
        return font:GetPositionX(), font:GetPositionY();
    end);
    if (ok and type(x) == 'number' and type(y) == 'number') then
        position[1] = x;
        position[2] = y;
    end
end


local function update_message_fonts()
    if (learned_font == nil or used_font == nil) then
        return;
    end

    if (is_addon_hide_menu_open()) then
        set_message_font_visible(learned_font, false);
        set_message_font_visible(used_font, false);
        return;
    end

    local learned_visible = state.learn_message_test or
        (state.learn_message_enabled[1] and state.learn_message ~= '' and
         os.time() < state.learn_message_until);
    if (not state.learn_message_test and state.learn_message ~= '' and
            os.time() >= state.learn_message_until) then
        state.learn_message = '';
    end
    learned_font:SetFontHeight(math.max(8, math.floor(13 * state.learn_message_scale[1] + 0.5)));
    local learned_text = state.learn_message_test and
        'Blue Magic learned: Test Spell! (drag to move)' or state.learn_message;
    learned_font:SetText(learned_visible and learned_text or '');
    learned_font:SetLocked(not state.learn_message_test);
    set_message_font_visible(learned_font, learned_visible);
    if (state.learn_message_test) then
        read_font_position(learned_font, state.learn_message_position);
    end

    local used_lines = {};
    if (state.mob_spell_message_test) then
        used_lines[1] = state.show_mob_ids[1] and
            'Walking Sapling [ID: BCD] - drag to move' or
            'Walking Sapling - drag to move';
        used_lines[2] = '  Sprout Smack (2)';
        used_lines[3] = '';
        used_lines[4] = state.show_mob_ids[1] and
            'Young Quadav [ID: BCE]' or 'Young Quadav';
        used_lines[5] = '  No Blue Magic used';
    else
        for _, actor_id in ipairs(state.mob_spell_tracker_order) do
            local tracker = state.mob_spell_trackers[actor_id];
            if (tracker ~= nil) then
                if (#used_lines > 0) then
                    used_lines[#used_lines + 1] = '';
                end
                if (state.show_mob_ids[1]) then
                    used_lines[#used_lines + 1] = ('%s [ID: %03X]'):fmt(
                        tracker.name, tracker.actor_id % 0x1000
                    );
                else
                    used_lines[#used_lines + 1] = tracker.name;
                end
                local learnable_names = get_mob_learnable_spell_names(tracker.name);
                if (#learnable_names > 0) then
                    local colored_names = {};
                    for _, spell_name in ipairs(learnable_names) do
                        local color = is_blue_spell_known(spell_name) and
                            'FF59FF73' or 'FFFF4747';
                        colored_names[#colored_names + 1] =
                            ('|c%s|%s|r'):fmt(color, spell_name);
                    end
                    used_lines[#used_lines + 1] = '  Learnable: ' ..
                        table.concat(colored_names, ', ');
                end
                if (#tracker.spell_order == 0) then
                    used_lines[#used_lines + 1] = '  No Blue Magic used';
                else
                    for _, spell_name in ipairs(tracker.spell_order) do
                        used_lines[#used_lines + 1] = ('  %s (%d)'):fmt(
                            spell_name, tracker.counts[spell_name]
                        );
                    end
                end
            end
        end
    end
    local used_visible = state.mob_spell_message_test or
        (state.mob_spell_message_enabled[1] and #used_lines > 0);
    local shift_down = false;
    pcall(function ()
        local io = imgui.GetIO();
        shift_down = io.KeyShift == true;
    end);
    used_font:SetFontHeight(math.max(8, math.floor(13 * state.mob_spell_message_scale[1] + 0.5)));
    used_font:SetPadding(math.max(0,
        math.floor(5 * state.mob_spell_message_scale[1] + 0.5)));
    used_font:SetText(used_visible and table.concat(used_lines, '\n') or '');
    -- Some Ashita versions rebuild the background after changing the text.
    update_used_message_background();
    used_font:SetLocked(not state.mob_spell_message_test and not shift_down);
    set_message_font_visible(used_font, used_visible);
    if (state.mob_spell_message_test or shift_down) then
        read_font_position(used_font, state.mob_spell_message_position);
    end
    if (state.mob_move_shift_active and not shift_down) then
        save_settings();
    end
    state.mob_move_shift_active = shift_down;
end


local function toggle_message_tests()
    local testing = not (state.learn_message_test and state.mob_spell_message_test);
    state.learn_message_test = testing;
    state.mob_spell_message_test = testing;
    print(('[BluSpellbook] Message test %s.'):fmt(
        testing and 'enabled - drag both messages to move them' or
        'disabled and positions saved'
    ));
    if (not testing) then
        save_settings();
    end
end


local function print_command_help()
    print('[BluSpellbook] Commands:');
    print('  /bsb - Toggle the main Spellbook GUI.');
    print('  /bsb show - Open the main GUI when BLU is main or subjob.');
    print('  /bsb hide - Close the main GUI.');
    print('  /bsb refresh - Refresh learned-spell status from client memory.');
    print('  /bsb test - Toggle both draggable on-screen message previews.');
    print('  /bsb help - Display this command list.');
end

local function draw_main_tab_button(label, index, scale, normal_color, hover_color,
        selected_color, text_color)
    local button_color = state.active_tab == index and selected_color or normal_color;
    imgui.PushStyleColor(ImGuiCol_Button, button_color);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, hover_color);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, selected_color);
    imgui.PushStyleColor(ImGuiCol_Text, text_color);
    if (imgui.Button(label .. '##main_tab', { 120 * scale, 24 * scale })) then
        state.active_tab = index;
    end
    imgui.PopStyleColor(4);
end

local function draw_window()
    if (not state.is_open[1]) then
        return;
    end

    if (get_blue_mage_level() == nil) then
        return;
    end

    if (is_addon_hide_menu_open()) then
        return;
    end

    if (state.auto_hide_combat[1]) then
        local player = GetPlayerEntity();
        if (player ~= nil and player.Status == 1) then
            return;
        end
    end

    if (state.auto_hide_main_menu[1] and is_main_menu_open()) then
        return;
    end

    local scale = state.ui_scale[1];
    local style_count = push_scaled_style(scale);
    local font_state = push_scaled_font(scale);
    local control_color_count = push_control_style();
    push_title_bar_style();
    imgui.SetNextWindowSize({ 900 * scale, 520 * scale });
    if (imgui.Begin('Blue Mage Spellbook', state.is_open, ImGuiWindowFlags_NoResize)) then
        draw_main_tab_button('Spell Browser', 1, scale,
            { 0.09, 0.38, 0.54, 1.0 }, { 0.16, 0.59, 0.75, 1.0 },
            { 0.13, 0.52, 0.68, 1.0 }, { 0.95, 0.98, 1.00, 1.0 });
        imgui.SameLine();
        draw_main_tab_button('Job Traits', 2, scale,
            { 0.05, 0.22, 0.43, 1.0 }, { 0.08, 0.42, 0.68, 1.0 },
            { 0.07, 0.34, 0.62, 1.0 }, { 0.97, 0.99, 1.00, 1.0 });
        imgui.SameLine();
        draw_main_tab_button('Options', 3, scale,
            { 0.12, 0.17, 0.25, 1.0 }, { 0.15, 0.31, 0.48, 1.0 },
            { 0.10, 0.39, 0.62, 1.0 }, { 0.97, 0.99, 1.00, 1.0 });
        imgui.Separator();

            if (state.active_tab == 1) then
                imgui.SetNextItemWidth(150 * scale);
                if (imgui.Combo('##priority_filter', state.view_mode, 'Required\0Recommended\0All\0\0')) then
                    state.selected_spell_id = nil;
                end
                imgui.SameLine();
                if (imgui.Button('Refresh')) then
                    load_spells();
                end
                imgui.SameLine();
                imgui.TextColored({ 0.35, 1.0, 0.45, 1.0 }, 'Green learned');
                imgui.SameLine();
                imgui.TextDisabled('|');
                imgui.SameLine();
                imgui.TextColored({ 1.0, 0.82, 0.16, 1.0 }, 'Yellow ready');
                imgui.SameLine();
                imgui.TextDisabled('|');
                imgui.SameLine();
                imgui.TextColored({ 1.0, 0.28, 0.28, 1.0 }, 'Red locked');
                imgui.SameLine();
                local wiki_button_width = 170 * scale;
                local wiki_button_x = imgui.GetWindowWidth() - wiki_button_width - (10 * scale);
                imgui.SetCursorPosX(wiki_button_x);
                if (imgui.Button('HXI Blu Wiki', { wiki_button_width, 0 })) then
                    ashita.misc.open_url('https://horizonffxi.wiki/Blue_Mage');
                end
                imgui.Separator();

                imgui.BeginGroup();
                draw_range_column();
                imgui.EndGroup();
                imgui.SameLine();
                imgui.BeginGroup();
                draw_spell_list();
                imgui.EndGroup();
                imgui.SameLine();
                imgui.BeginGroup();
                draw_location_column();
                imgui.EndGroup();
            end

            if (state.active_tab == 2) then
                draw_job_traits();
            end

            if (state.active_tab == 3) then
                imgui.BeginChild('##options_scroll', { 0, -1 }, 0, 0);
                imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, 'Interface Scale');
                imgui.TextWrapped('Adjust the entire Blue Mage Spellbook proportionally, including text, spacing, columns, controls, and the window itself.');
                imgui.Checkbox('Open GUI when addon loads', state.show_on_load);
                imgui.Spacing();
                imgui.SetNextItemWidth(300 * scale);
                imgui.SliderFloat('GUI Scale', state.ui_scale, 0.50, 1.75, '%.2fx');
                imgui.SameLine();
                push_red_button_style();
                if (imgui.Button('Reset')) then
                    state.ui_scale[1] = 0.75;
                end
                imgui.PopStyleColor(3);
                imgui.Separator();
                imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, 'Combat Behavior');
                imgui.Checkbox('Auto-hide while engaged', state.auto_hide_combat);
                imgui.TextWrapped('When enabled, the window hides during combat and automatically returns after disengaging.');
                imgui.Separator();
                imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, 'Menu Behavior');
                imgui.Checkbox('Auto-hide while the main menu is open', state.auto_hide_main_menu);
                imgui.TextWrapped('Hides only for the right-side FFXI main menu. The lower-left Attack, Magic, Abilities, Items, and Disengage command menu will not hide the spellbook.');
                imgui.Separator();
                imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, 'Learned Spell Message');
                imgui.TextWrapped('Adjust the size of the five-second learned-spell notification. Use /bsb test to preview and move it.');
                imgui.Checkbox('Enable learned-spell message', state.learn_message_enabled);
                imgui.SetNextItemWidth(300 * scale);
                imgui.SliderFloat('Message Scale', state.learn_message_scale, 0.75, 2.50, '%.2fx');
                imgui.SameLine();
                push_red_button_style();
                if (imgui.Button('Message Reset')) then
                    state.learn_message_scale[1] = 1.25;
                end
                imgui.PopStyleColor(3);
                imgui.Separator();
                imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, 'Blue Magic Used Message');
                imgui.TextWrapped('Adjust the persistent monster Blue Magic use counter. Use /bsb test or Test Messages to preview and move it.');
                imgui.TextWrapped('During normal use, hold Shift and click-drag the list to move it. The position saves when Shift is released.');
                imgui.Checkbox('Enable Blue Magic used message', state.mob_spell_message_enabled);
                imgui.Checkbox('Detect spells even when already known', state.detect_known_spells);
                imgui.TextWrapped('When enabled, mobs and move counters remain eligible even after their Blue Magic spell has been learned.');
                imgui.Checkbox('Show mob IDs', state.show_mob_ids);
                imgui.SetNextItemWidth(300 * scale);
                imgui.SliderFloat('List Background Opacity', state.mob_list_background_opacity, 0.0, 1.0, '%.2f');
                imgui.SetNextItemWidth(300 * scale);
                imgui.SliderFloat('Used Message Scale', state.mob_spell_message_scale, 0.75, 2.50, '%.2fx');
                imgui.SameLine();
                push_red_button_style();
                if (imgui.Button('Used Reset')) then
                    state.mob_spell_message_scale[1] = 1.25;
                end
                imgui.PopStyleColor(3);
                imgui.Separator();
                imgui.Spacing();
                local test_label = state.learn_message_test and state.mob_spell_message_test and
                    'Stop Message Test' or 'Test Messages';
                if (imgui.Button(test_label, { 150 * scale, 34 * scale })) then
                    toggle_message_tests();
                end
                imgui.SameLine();
                push_gold_button_style();
                if (imgui.Button('Save Settings', { 150 * scale, 34 * scale })) then
                    save_settings();
                end
                imgui.PopStyleColor(3);
                imgui.SameLine();
                push_red_button_style();
                if (imgui.Button('Reset All Settings', { 170 * scale, 34 * scale })) then
                    reset_settings_to_defaults();
                end
                imgui.PopStyleColor(3);
                imgui.SameLine();
                if (imgui.Button('README', { 120 * scale, 34 * scale })) then
                    state.readme_do_not_show_again[1] = false;
                    state.show_readme_window[1] = true;
                end
                if (state.settings_message ~= '') then
                    imgui.TextColored({ 0.35, 1.0, 0.45, 1.0 }, state.settings_message);
                end
                imgui.EndChild();
            end
    end
    imgui.End();
    imgui.PopStyleColor(3);
    imgui.PopStyleColor(control_color_count);
    pop_scaled_font(font_state);
    imgui.PopStyleVar(style_count);
end


local function draw_readme_window()
    hide_readme_banner();
    if (not state.show_readme_window[1]) then
        return;
    end
    if (is_addon_hide_menu_open()) then
        return;
    end

    local scale = state.ui_scale[1];
    local style_count = push_scaled_style(scale);
    local font_state = push_scaled_font(scale);
    local control_color_count = push_control_style();
    push_title_bar_style();
    imgui.SetNextWindowSize({ 1050 * scale, 700 * scale });
    if (imgui.Begin('BluSpellbook README', state.show_readme_window,
            ImGuiWindowFlags_NoResize + ImGuiWindowFlags_NoBackground)) then
        local banner_drawn = false;
        if (readme_banner ~= nil) then
            local cursor_x, cursor_y = imgui.GetCursorScreenPos();
            local banner_width = 748 * scale;
            local banner_height = banner_width / 3.0;
            readme_banner.position_x = cursor_x + (200 * scale);
            readme_banner.position_y = cursor_y;
            readme_banner.scale_x = banner_width / 1024.0;
            readme_banner.scale_y = banner_height / 341.0;
            readme_banner.visible = true;
            imgui.Dummy({ 0, banner_height });
            banner_drawn = true;
        end
        if (not banner_drawn) then
            imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 },
                'Welcome to BluSpellbook');
        end
        imgui.Separator();
        imgui.PushStyleColor(ImGuiCol_ChildBg, { 0.165, 0.255, 0.405, 0.94 });
        imgui.BeginChild('##bluspellbook_readme_scroll',
            { 0, -48 * scale }, 1, 0);
        if (#state.readme_lines == 0) then
            imgui.TextWrapped('README.md is empty.');
        else
            -- Draw one line at a time so long README text is not cut off.
            for _, line in ipairs(state.readme_lines) do
                if (line == '') then
                    imgui.Spacing();
                else
                    imgui.TextWrapped(line);
                end
            end
        end
        imgui.EndChild();
        imgui.PopStyleColor(1);
        imgui.Separator();
        imgui.PushStyleColor(ImGuiCol_ChildBg, { 0.165, 0.255, 0.405, 0.94 });
        imgui.BeginChild('##bluspellbook_readme_footer',
            { 0, 36 * scale }, 0, 0);
        if (imgui.Checkbox('Do not show again',
                state.readme_do_not_show_again) and
                state.readme_do_not_show_again[1]) then
            state.readme_dismissed = true;
            state.show_readme_window[1] = false;
            save_settings();
        end
        imgui.EndChild();
        imgui.PopStyleColor(1);
    end
    imgui.End();
    imgui.PopStyleColor(3);
    imgui.PopStyleColor(control_color_count);
    pop_scaled_font(font_state);
    imgui.PopStyleVar(style_count);
end

ashita.events.register('load', 'load_cb', function ()
    load_settings();
    state.is_open[1] = state.show_on_load[1];
    load_readme_contents();
    create_readme_banner();
    create_message_fonts();
    load_locations();
    load_spells();
    refresh_known_spells();
    select_current_level_range();
    state.load_refresh_at = os.clock() + 1.0;
    state.known_refresh_at = os.clock() + 0.5;
end);

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    if (#args > 0 and args[1]:any('/sea', '/search')) then
        -- Start hiding just before the player-search window opens.
        player_search_menu_latched = true;
        player_search_menu_seen = false;
        player_search_command_armed_until = os.clock() + 5.0;
        player_search_transition_hold_until = 0;
        return;
    end
    if (#args == 0 or not args[1]:any('/bluspellbook', '/bluspells', '/bsb')) then
        return;
    end

    e.blocked = true;
    if (#args == 1 or args[2]:any('toggle')) then
        state.is_open[1] = not state.is_open[1];
    elseif (args[2]:any('show', 'open')) then
        state.is_open[1] = true;
    elseif (args[2]:any('hide', 'close')) then
        state.is_open[1] = false;
    elseif (args[2]:any('refresh')) then
        load_spells();
    elseif (args[2]:any('test', 'testdisplay')) then
        toggle_message_tests();
    elseif (args[2]:any('help', '?')) then
        print_command_help();
    end
end);

-- Use combat messages when Game does not provide a dependable move number.
ashita.events.register('text_in', 'text_in_cb', function (e)
    if (e.injected) then return; end
    local message = e.message_modified;
    if (type(message) ~= 'string' or message == '') then
        message = e.message;
    end
    if (type(message) ~= 'string') then return; end
    local lower_message = message:lower();

    -- Remove dead enemies that Game leaves behind in memory.
    if (lower_message:find(' defeats ', 1, true) ~= nil or
            lower_message:find('falls to the ground', 1, true) ~= nil or
            lower_message:find(' is defeated', 1, true) ~= nil) then
        for tracker_index = #state.mob_spell_tracker_order, 1, -1 do
            local actor_id = state.mob_spell_tracker_order[tracker_index];
            local tracker = state.mob_spell_trackers[actor_id];
            if (tracker ~= nil and type(tracker.name) == 'string' and
                    lower_message:find(tracker.name:lower(), 1, true) ~= nil) then
                remove_mob_spell_tracker(actor_id);
            end
        end
    end

    local is_monster_move = lower_message:find(' uses ', 1, true) ~= nil or
        lower_message:find(' readies ', 1, true) ~= nil;
    if (not is_monster_move) then return; end

    local spell_name = nil;
    local longest_match = 0;
    for _, spell in ipairs(state.spells) do
        local candidate = spell.name:lower();
        if (#candidate > longest_match and lower_message:find(candidate, 1, true) ~= nil) then
            spell_name = spell.name;
            longest_match = #candidate;
        end
        if (spell.name == 'Vanity Dive' and
                lower_message:find('vanity drive', 1, true) ~= nil) then
            spell_name = spell.name;
            longest_match = 12;
        end
        if (spell.name == 'Empty Thrash' and
                lower_message:find('empty trash', 1, true) ~= nil) then
            spell_name = spell.name;
            longest_match = 11;
        end
        if (spell.name == 'Winds of Promy.' and
                lower_message:find('winds of promyvion', 1, true) ~= nil) then
            spell_name = spell.name;
            longest_match = 18;
        end
        if (spell.name == 'Quad. Continuum' and
                lower_message:find('quadratic continuum', 1, true) ~= nil) then
            spell_name = spell.name;
            longest_match = 19;
        end
    end
    for spell_id, _ in pairs(state.locations) do
        local resource = AshitaCore:GetResourceManager():GetSpellById(tonumber(spell_id));
        if (resource ~= nil and resource.Name ~= nil) then
            local resource_name = get_english_resource_name(resource.Name);
            if (type(resource_name) == 'string') then
                local candidate = resource_name:lower();
                if (#candidate > longest_match and
                        lower_message:find(candidate, 1, true) ~= nil) then
                    spell_name = resource_name;
                    longest_match = #candidate;
                end
            end
        end
    end
    if (spell_name == nil) then return; end

    local tracker = nil;
    local pending_tracker = nil;
    if (state.pending_mob_move_actor_id ~= nil and
            os.clock() <= state.pending_mob_move_until) then
        pending_tracker = state.mob_spell_trackers[state.pending_mob_move_actor_id] or
            ensure_mob_spell_tracker(state.pending_mob_move_actor_id);
        -- Check the enemy's name so the move is not counted for the wrong enemy.
        if (pending_tracker ~= nil and type(pending_tracker.name) == 'string' and
                lower_message:find(pending_tracker.name:lower(), 1, true) ~= nil) then
            tracker = pending_tracker;
        end
    end

    -- Use the name shown in chat when several enemies prepare moves at once.
    if (tracker == nil) then
        for _, actor_id in ipairs(state.mob_spell_tracker_order) do
            local candidate = state.mob_spell_trackers[actor_id];
            if (candidate ~= nil and type(candidate.name) == 'string' and
                    lower_message:find(candidate.name:lower(), 1, true) ~= nil) then
                tracker = candidate;
                break;
            end
        end
    end
    if (tracker == nil) then
        tracker = pending_tracker;
    end
    increment_mob_spell(tracker, spell_name);
end);

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    if (e.id == 0x000E) then
        local entity_index = struct.unpack('H', e.data_modified, 0x08 + 0x01);
        local flags = struct.unpack('B', e.data_modified, 0x0A + 0x01);
        if (flags % 4 >= 2) then
            local claim_id = struct.unpack('L', e.data_modified, 0x2C + 0x01);
            local party_ids = get_party_server_ids();
            if (party_ids[claim_id]) then
                local entity = AshitaCore:GetMemoryManager():GetEntity();
                local ok, server_id = pcall(function ()
                    return entity:GetServerId(entity_index);
                end);
                if (ok and server_id ~= nil and server_id ~= 0) then
                    ensure_mob_spell_tracker(server_id);
                end
            end
        end
        return;
    end

    -- Game uses 7 when a move starts and 11 when it finishes.
    if (e.id == 0x0028) then
        local category = ashita.bits.unpack_be(e.data_raw, 82, 4);
        local target_count = ashita.bits.unpack_be(e.data_raw, 72, 10);
        local actor_id = ashita.bits.unpack_be(e.data_raw, 40, 32);
        if (target_count > 0) then
            local first_target_id = ashita.bits.unpack_be(e.data_raw, 150, 32);
            track_party_enmity_action(actor_id, first_target_id);
        end
        if (category == 7 or category == 11) then
            local ability_id = ashita.bits.unpack_be(e.data_raw, 86, 16);
            state.pending_mob_move_actor_id = actor_id;
            state.pending_mob_move_until = os.clock() + 8.0;
            record_mob_blue_spell(actor_id, ability_id);
        end
        return;
    end

    if (e.id == 0x0029) then
        -- Remove the extra marker from the message number.
        local message_id = struct.unpack('H', e.data_modified, 0x18 + 0x01) % 0x8000;
        local actor_id = struct.unpack('L', e.data_modified, 0x04 + 0x01);
        local target_id = struct.unpack('L', e.data_modified, 0x08 + 0x01);
        local is_death_message = message_id == 6 or message_id == 20 or
            message_id == 113 or message_id == 406 or message_id == 605 or
            message_id == 646;
        if (is_death_message) then
            if (state.mob_spell_trackers[target_id] ~= nil) then
                remove_mob_spell_tracker(target_id);
            end
            if (state.mob_spell_trackers[actor_id] ~= nil) then
                remove_mob_spell_tracker(actor_id);
            end
        end
        if (message_id == 419) then
            local spell_id = struct.unpack('L', e.data_modified, 0x0C + 0x01);

            -- Keep the learned result while the game catches up.
            for _, spell in ipairs(state.spells) do
                if (spell.id == spell_id) then
                    spell.known = true;
                    state.learned_refresh_at = os.clock() + 1.0;
                    state.learned_refresh_spell_id = spell_id;
                    state.learn_message = ('Blue Magic learned: %s!'):fmt(spell.name);
                    state.learn_message_until = os.time() + 5;
                    break;
                end
            end
        end
        return;
    end

    if (e.id == 0x00AA) then
        load_spells();
    end
end);

ashita.events.register('d3d_present', 'present_cb', function ()
    if (state.load_refresh_at ~= nil and os.clock() >= state.load_refresh_at) then
        state.load_refresh_at = nil;
        load_spells();
        select_current_level_range();
    end

    if (state.known_refresh_at ~= nil and os.clock() >= state.known_refresh_at) then
        refresh_known_spells();
        -- Game may take a moment to load known spells after reloading the addon.
        state.known_refresh_at = os.clock() + 2.0;
    end

    if (state.learned_refresh_at ~= nil and os.clock() >= state.learned_refresh_at) then
        local learned_spell_id = state.learned_refresh_spell_id;
        state.learned_refresh_at = nil;
        state.learned_refresh_spell_id = nil;
        load_spells();
        -- Keep newly learned spells marked while a refresh finishes.
        for _, spell in ipairs(state.spells) do
            if (spell.id == learned_spell_id) then
                spell.known = true;
                break;
            end
        end
    end
    track_party_battle_targets();
    update_mob_spell_tracker();
    draw_readme_window();
    draw_window();
    update_message_fonts();
end);

ashita.events.register('unload', 'unload_cb', function ()
    read_font_position(learned_font, state.learn_message_position);
    read_font_position(used_font, state.mob_spell_message_position);
    save_settings();
    local manager = AshitaCore:GetFontManager();
    pcall(function () manager:Delete('bluspellbook_learned_message'); end);
    pcall(function () manager:Delete('bluspellbook_used_message'); end);
    if (readme_banner ~= nil) then
        pcall(function () readme_banner:destroy(); end);
        readme_banner = nil;
    end
end);
